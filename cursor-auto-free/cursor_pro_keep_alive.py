import os
import platform
import json
import sys
import subprocess
from colorama import Fore, Style
from enum import Enum
from typing import Optional

from exit_cursor import ExitCursor
import go_cursor_help
import patch_cursor_get_machine_id
from reset_machine import MachineIDResetter

os.environ["PYTHONVERBOSE"] = "0"
os.environ["PYINSTALLER_VERBOSE"] = "0"

import time
import random
from cursor_auth_manager import CursorAuthManager
import os
from logger import logging
from browser_utils import BrowserManager
from get_email_code import EmailVerificationHandler
from logo import print_logo
from config import Config
from datetime import datetime

# 定义 EMOJI 字典
EMOJI = {"ERROR": "❌", "WARNING": "⚠️", "INFO": "ℹ️"}


class VerificationStatus(Enum):
    """验证状态枚举"""

    PASSWORD_PAGE = "@name=password"
    CAPTCHA_PAGE = "@data-index=0"
    ACCOUNT_SETTINGS = "Account Settings"


class TurnstileError(Exception):
    """Turnstile 验证相关异常"""

    pass


def save_screenshot(tab, stage: str, timestamp: bool = True) -> None:
    """
    保存页面截图

    Args:
        tab: 浏览器标签页对象
        stage: 截图阶段标识
        timestamp: 是否添加时间戳
    """
    try:
        # 创建 screenshots 目录
        screenshot_dir = "screenshots"
        if not os.path.exists(screenshot_dir):
            os.makedirs(screenshot_dir)

        # 生成文件名
        if timestamp:
            filename = f"turnstile_{stage}_{int(time.time())}.png"
        else:
            filename = f"turnstile_{stage}.png"

        filepath = os.path.join(screenshot_dir, filename)

        # 保存截图
        tab.get_screenshot(filepath)
        logging.debug(f"截图已保存: {filepath}")
    except Exception as e:
        logging.warning(f"截图保存失败: {str(e)}")


def check_verification_success(tab) -> Optional[VerificationStatus]:
    """
    检查验证是否成功

    Returns:
        VerificationStatus: 验证成功时返回对应状态，失败返回 None
    """
    for status in VerificationStatus:
        if tab.ele(status.value):
            logging.info(f"验证成功 - 已到达{status.name}页面")
            return status
    return None


def handle_turnstile(tab, max_retries: int = 2, retry_interval: tuple = (1, 2)) -> bool:
    """
    处理 Turnstile 验证

    Args:
        tab: 浏览器标签页对象
        max_retries: 最大重试次数
        retry_interval: 重试间隔时间范围(最小值, 最大值)

    Returns:
        bool: 验证是否成功

    Raises:
        TurnstileError: 验证过程中出现异常
    """
    logging.info("正在检测 Turnstile 验证...")
    save_screenshot(tab, "start")

    retry_count = 0

    try:
        while retry_count < max_retries:
            retry_count += 1
            logging.debug(f"第 {retry_count} 次尝试验证")

            try:
                # 定位验证框元素
                challenge_check = (
                    tab.ele("@id=cf-turnstile", timeout=2)
                    .child()
                    .shadow_root.ele("tag:iframe")
                    .ele("tag:body")
                    .sr("tag:input")
                )

                if challenge_check:
                    logging.info("检测到 Turnstile 验证框，开始处理...")
                    # 随机延时后点击验证
                    time.sleep(random.uniform(1, 3))
                    challenge_check.click()
                    time.sleep(2)

                    # 保存验证后的截图
                    save_screenshot(tab, "clicked")

                    # 检查验证结果
                    if check_verification_success(tab):
                        logging.info("Turnstile 验证通过")
                        save_screenshot(tab, "success")
                        return True

            except Exception as e:
                logging.debug(f"当前尝试未成功: {str(e)}")

            # 检查是否已经验证成功
            if check_verification_success(tab):
                return True

            # 随机延时后继续下一次尝试
            time.sleep(random.uniform(*retry_interval))

        # 超出最大重试次数
        logging.error(f"验证失败 - 已达到最大重试次数 {max_retries}")
        logging.error(
            "请前往开源项目查看更多信息：https://github.com/chengazhen/cursor-auto-free"
        )
        save_screenshot(tab, "failed")
        return False

    except Exception as e:
        error_msg = f"Turnstile 验证过程发生异常: {str(e)}"
        logging.error(error_msg)
        save_screenshot(tab, "error")
        raise TurnstileError(error_msg)


def get_cursor_session_token(tab, max_attempts=3, retry_interval=2):
    """
    获取Cursor会话token，带有重试机制
    :param tab: 浏览器标签页
    :param max_attempts: 最大尝试次数
    :param retry_interval: 重试间隔(秒)
    :return: session token 或 None
    """
    logging.info("开始获取cookie")
    attempts = 0

    while attempts < max_attempts:
        try:
            cookies = tab.cookies()
            for cookie in cookies:
                if cookie.get("name") == "WorkosCursorSessionToken":
                    token_value = cookie["value"]
                    # 处理不同格式的token
                    if "%3A%3A" in token_value:
                        token = token_value.split("%3A%3A")[1]
                        logging.info(f"找到带有%3A%3A分隔符的token: {token[:10]}...")
                        return token
                    elif "::" in token_value:
                        token = token_value.split("::")[1]
                        logging.info(f"找到带有::分隔符的token: {token[:10]}...")
                        return token
                    else:
                        # 如果没有分隔符，直接返回token值
                        logging.info(f"Token没有分隔符，直接返回完整token: {token_value[:10]}...")
                        return token_value
            
            attempts += 1
            if attempts < max_attempts:
                logging.warning(
                    f"第 {attempts} 次尝试未获取到CursorSessionToken，{retry_interval}秒后重试..."
                )
                time.sleep(retry_interval)
            else:
                logging.error(
                    f"已达到最大尝试次数({max_attempts})，获取CursorSessionToken失败"
                )

        except Exception as e:
            logging.error(f"获取cookie失败: {str(e)}")
            attempts += 1
            if attempts < max_attempts:
                logging.info(f"将在 {retry_interval} 秒后重试...")
                time.sleep(retry_interval)

    return None


def update_cursor_auth(email=None, access_token=None, refresh_token=None):
    """
    更新Cursor的认证信息的便捷函数
    """
    auth_manager = CursorAuthManager()
    return auth_manager.update_auth(email, access_token, refresh_token)


def sign_up_account(browser, tab):
    logging.info("=== 开始注册账号流程 ===")
    logging.info(f"正在访问注册页面: {sign_up_url}")
    tab.get(sign_up_url)

    try:
        if tab.ele("@name=first_name"):
            logging.info("正在填写个人信息...")
            tab.actions.click("@name=first_name").input(first_name)
            logging.info(f"已输入名字: {first_name}")
            time.sleep(random.uniform(1, 3))

            tab.actions.click("@name=last_name").input(last_name)
            logging.info(f"已输入姓氏: {last_name}")
            time.sleep(random.uniform(1, 3))

            tab.actions.click("@name=email").input(account)
            logging.info(f"已输入邮箱: {account}")
            time.sleep(random.uniform(1, 3))

            logging.info("提交个人信息...")
            tab.actions.click("@type=submit")

    except Exception as e:
        logging.error(f"注册页面访问失败: {str(e)}")
        return False

    handle_turnstile(tab)

    try:
        if tab.ele("@name=password"):
            logging.info("正在设置密码...")
            tab.ele("@name=password").input(password)
            time.sleep(random.uniform(1, 3))

            logging.info("提交密码...")
            tab.ele("@type=submit").click()
            logging.info("密码设置完成，等待系统响应...")

    except Exception as e:
        logging.error(f"密码设置失败: {str(e)}")
        return False

    if tab.ele("This email is not available."):
        logging.error("注册失败：邮箱已被使用")
        return False

    handle_turnstile(tab)

    while True:
        try:
            if tab.ele("Account Settings"):
                logging.info("注册成功 - 已进入账户设置页面")
                break
            if tab.ele("@data-index=0"):
                logging.info("正在获取邮箱验证码...")
                code = email_handler.get_verification_code()
                if not code:
                    logging.error("获取验证码失败")
                    return False

                logging.info(f"成功获取验证码: {code}")
                logging.info("正在输入验证码...")
                i = 0
                for digit in code:
                    tab.ele(f"@data-index={i}").input(digit)
                    time.sleep(random.uniform(0.1, 0.3))
                    i += 1
                logging.info("验证码输入完成")
                break
        except Exception as e:
            logging.error(f"验证码处理过程出错: {str(e)}")

    handle_turnstile(tab)
    wait_time = random.randint(3, 6)
    for i in range(wait_time):
        logging.info(f"等待系统处理中... 剩余 {wait_time-i} 秒")
        time.sleep(1)

    logging.info("正在获取账户信息...")
    tab.get(settings_url)
    try:
        usage_selector = (
            "css:div.col-span-2 > div > div > div > div > "
            "div:nth-child(1) > div.flex.items-center.justify-between.gap-2 > "
            "span.font-mono.text-sm\\/\\[0\\.875rem\\]"
        )
        usage_ele = tab.ele(usage_selector)
        if usage_ele:
            usage_info = usage_ele.text
            total_usage = usage_info.split("/")[-1].strip()
            logging.info(f"账户可用额度上限: {total_usage}")
            logging.info(
                "请前往开源项目查看更多信息：https://github.com/chengazhen/cursor-auto-free"
            )
    except Exception as e:
        logging.error(f"获取账户额度信息失败: {str(e)}")

    logging.info("\n=== 注册完成 ===")
    account_info = f"Cursor 账号信息:\n邮箱: {account}\n密码: {password}"
    logging.info(account_info)
    time.sleep(5)
    return True


class EmailGenerator:
    def __init__(
        self,
        password="".join(
            random.choices(
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*",
                k=12,
            )
        ),
    ):
        configInstance = Config()
        configInstance.print_config()
        self.domain = configInstance.get_domain()
        self.names = self.load_names()
        self.default_password = password
        self.default_first_name = self.generate_random_name()
        self.default_last_name = self.generate_random_name()

    def load_names(self):
        with open("names-dataset.txt", "r") as file:
            return file.read().split()

    def generate_random_name(self):
        """生成随机用户名"""
        return random.choice(self.names)

    def generate_email(self, length=4):
        """生成随机邮箱地址"""
        length = random.randint(0, length)  # 生成0到length之间的随机整数
        timestamp = str(int(time.time()))[-length:]  # 使用时间戳后length位
        return f"{self.default_first_name}{timestamp}@{self.domain}"  #

    def get_account_info(self):
        """获取完整的账号信息"""
        return {
            "email": self.generate_email(),
            "password": self.default_password,
            "first_name": self.default_first_name,
            "last_name": self.default_last_name,
        }


def get_user_agent():
    """获取user_agent"""
    try:
        # 使用JavaScript获取user agent
        browser_manager = BrowserManager()
        browser = browser_manager.init_browser()
        user_agent = browser.latest_tab.run_js("return navigator.userAgent")
        browser_manager.quit()
        return user_agent
    except Exception as e:
        logging.error(f"获取user agent失败: {str(e)}")
        return None


def print_end_message():
    logging.info("\n\n\n\n\n")
    logging.info("=" * 30)
    logging.info("所有操作已完成")
    logging.info("\n=== 获取更多信息 ===")
    logging.info("📺 B站UP主: 想回家的前端")
    logging.info("🔥 公众号: code 未来")
    logging.info("=" * 30)
    logging.info(
        "请前往开源项目查看更多信息：https://github.com/chengazhen/cursor-auto-free"
    )


def launch_cursor_ide():
    """在独立进程中启动Cursor IDE"""
    try:
        logging.info("正在启动Cursor IDE...")
        
        # 根据操作系统选择启动命令
        if platform.system() == "Windows":
            # Windows路径中可能存在的程序位置
            possible_paths = [
                os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Cursor', 'Cursor.exe'),
                os.path.join(os.environ.get('PROGRAMFILES', ''), 'Cursor', 'Cursor.exe'),
                os.path.join(os.environ.get('PROGRAMFILES(X86)', ''), 'Cursor', 'Cursor.exe')
            ]
            
            cursor_path = None
            for path in possible_paths:
                if os.path.exists(path):
                    cursor_path = path
                    break
            
            if cursor_path:
                # 使用subprocess.Popen启动新进程，与当前进程分离
                subprocess.Popen([cursor_path], creationflags=subprocess.DETACHED_PROCESS)
                logging.info(f"Cursor IDE已在单独进程中启动: {cursor_path}")
            else:
                logging.error("未找到Cursor IDE可执行文件")
                
        elif platform.system() == "Darwin":  # macOS
            subprocess.Popen(["open", "-a", "Cursor"], start_new_session=True)
            logging.info("Cursor IDE已在单独进程中启动")
            
        elif platform.system() == "Linux":
            subprocess.Popen(["cursor"], start_new_session=True)
            logging.info("Cursor IDE已在单独进程中启动")
            
        else:
            logging.error(f"不支持的操作系统: {platform.system()}")
            
    except Exception as e:
        logging.error(f"启动Cursor IDE时出错: {str(e)}")


def run_script():
    """主函数，包含自动重启逻辑"""
    print_logo()
    browser_manager = None
    success = False  # 用于跟踪脚本是否成功完成
    
    try:
        logging.info("\n=== 初始化程序 ===")
        ExitCursor()

        # 自动选择选项2（完整注册流程）
        choice = 2
        logging.info("自动选择选项2: 完整注册流程")

        logging.info("正在初始化浏览器...")

        # 获取user_agent
        user_agent = get_user_agent()
        if not user_agent:
            logging.error("获取user agent失败，使用默认值")
            user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        # 剔除user_agent中的"HeadlessChrome"
        user_agent = user_agent.replace("HeadlessChrome", "Chrome")

        browser_manager = BrowserManager()
        browser = browser_manager.init_browser(user_agent)

        # 获取并打印浏览器的user-agent
        user_agent = browser.latest_tab.run_js("return navigator.userAgent")

        logging.info(
            "请前往开源项目查看更多信息：https://github.com/chengazhen/cursor-auto-free"
        )
        logging.info("\n=== 配置信息 ===")
        global login_url, sign_up_url, settings_url, mail_url, first_name, last_name, account, password, email_handler
        login_url = "https://authenticator.cursor.sh"
        sign_up_url = "https://authenticator.cursor.sh/sign-up"
        settings_url = "https://www.cursor.com/settings"
        mail_url = "https://tempmail.plus"

        logging.info("正在生成随机账号信息...")

        email_generator = EmailGenerator()
        first_name = email_generator.default_first_name
        last_name = email_generator.default_last_name
        account = email_generator.generate_email()
        password = email_generator.default_password

        logging.info(f"生成的邮箱账号: {account}")

        logging.info("正在初始化邮箱验证模块...")
        email_handler = EmailVerificationHandler(account)

        auto_update_cursor_auth = True

        tab = browser.latest_tab

        tab.run_js("try { turnstile.reset() } catch(e) { }")

        logging.info("\n=== 开始注册流程 ===")
        logging.info(f"正在访问登录页面: {login_url}")
        tab.get(login_url)

        if sign_up_account(browser, tab):
            logging.info("正在获取会话令牌...")
            token = get_cursor_session_token(tab)
            if token:
                logging.info(f"成功获取到会话令牌，长度：{len(token)}")
                try:
                    logging.info("更新认证信息...")
                    update_result = update_cursor_auth(
                        email=account, access_token=token, refresh_token=token
                    )
                    if update_result:
                        logging.info("认证信息更新成功")
                    else:
                        logging.error("认证信息更新失败，但继续执行其他操作")
                except Exception as e:
                    logging.error(f"更新认证信息时出错: {str(e)}")
                
                logging.info(
                    "请前往开源项目查看更多信息：https://github.com/chengazhen/cursor-auto-free"
                )
                logging.info("重置机器码...")
                MachineIDResetter().reset_machine_ids()
                logging.info("所有操作已完成")
                success = True  # 标记脚本成功完成
                print_end_message()
            else:
                logging.error("获取会话令牌失败，注册流程未完成")
                # 未成功完成，设置success为False
        else:
            logging.error("注册账号失败，脚本未完成")
            # 未成功完成，设置success为False

    except Exception as e:
        logging.error(f"程序执行出现错误: {str(e)}")
        import traceback
        logging.error(traceback.format_exc())
        # 出现异常，设置success为False
        
    finally:
        if browser_manager:
            browser_manager.quit()
        
        if success:
            # 如果脚本成功完成，启动Cursor IDE
            launch_cursor_ide()
            logging.info("脚本已成功完成，Cursor IDE已启动")
        else:
            # 如果脚本未成功完成，重新启动脚本
            logging.warning("脚本未成功完成，即将重新启动...")
            time.sleep(3)  # 等待3秒后重启
            # 使用python命令重新启动当前脚本
            python_executable = sys.executable
            os.execl(python_executable, python_executable, *sys.argv)


if __name__ == "__main__":
    run_script()
