import sqlite3
import os
import sys


class CursorAuthManager:
    """Cursor认证信息管理器"""

    def __init__(self):
        # 判断操作系统
        if sys.platform == "win32":  # Windows
            appdata = os.getenv("APPDATA")
            if appdata is None:
                raise EnvironmentError("APPDATA 环境变量未设置")
            self.db_path = os.path.join(
                appdata, "Cursor", "User", "globalStorage", "state.vscdb"
            )
        elif sys.platform == "darwin": # macOS
            self.db_path = os.path.abspath(os.path.expanduser(
                "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
            ))
        elif sys.platform == "linux" : # Linux 和其他类Unix系统
            self.db_path = os.path.abspath(os.path.expanduser(
                "~/.config/Cursor/User/globalStorage/state.vscdb"
            ))
        else:
            raise NotImplementedError(f"不支持的操作系统: {sys.platform}")

    def update_auth(self, email=None, access_token=None, refresh_token=None):
        """
        更新Cursor的认证信息
        :param email: 新的邮箱地址
        :param access_token: 新的访问令牌
        :param refresh_token: 新的刷新令牌
        :return: bool 是否成功更新
        """
        updates = []
        # 登录状态
        updates.append(("cursorAuth/cachedSignUpType", "Auth_0"))

        if email is not None:
            updates.append(("cursorAuth/cachedEmail", email))
        if access_token is not None:
            updates.append(("cursorAuth/accessToken", access_token))
        if refresh_token is not None:
            updates.append(("cursorAuth/refreshToken", refresh_token))

        if not updates:
            print("没有提供任何要更新的值")
            return False

        conn = None
        try:
            if not os.path.exists(self.db_path):
                print(f"数据库文件不存在: {self.db_path}")
                return False

            # 检查文件是否可访问
            if not os.access(self.db_path, os.R_OK | os.W_OK):
                print(f"数据库文件不可读写: {self.db_path}")
                if sys.platform == "win32" and os.path.exists(self.db_path):
                    # 在Windows上尝试修复权限
                    try:
                        os.chmod(self.db_path, 0o666)
                        print(f"已尝试修复权限: {self.db_path}")
                    except Exception as e:
                        print(f"修复权限失败: {str(e)}")
                return False

            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            # 检查表是否存在
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='itemTable'")
            if not cursor.fetchone():
                print("数据库表不存在，创建新表")
                cursor.execute("CREATE TABLE itemTable (key TEXT PRIMARY KEY, value TEXT)")
                conn.commit()

            for key, value in updates:
                try:
                    # 如果没有更新任何行,说明key不存在,执行插入
                    # 检查 key 是否存在
                    check_query = "SELECT COUNT(*) FROM itemTable WHERE key = ?"
                    cursor.execute(check_query, (key,))
                    if cursor.fetchone()[0] == 0:
                        insert_query = "INSERT INTO itemTable (key, value) VALUES (?, ?)"
                        cursor.execute(insert_query, (key, value))
                        print(f"成功插入新键值: {key.split('/')[-1]}")
                    else:
                        update_query = "UPDATE itemTable SET value = ? WHERE key = ?"
                        cursor.execute(update_query, (value, key))
                        print(f"成功更新 {key.split('/')[-1]}")
                except Exception as e:
                    print(f"更新 {key} 时出错: {str(e)}")

            conn.commit()
            print(f"成功更新认证信息，共 {len(updates)} 项")
            return True

        except sqlite3.Error as e:
            print("数据库错误:", str(e))
            return False
        except Exception as e:
            print("发生错误:", str(e))
            return False
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass
