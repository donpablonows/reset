import { Browser, Page } from 'puppeteer'
import puppeteer from 'puppeteer'
import { randomBytes, createHash } from 'crypto'
import { v4 as uuidv4 } from 'uuid'
import axios, { AxiosInstance } from 'axios'

const randomStr = (length: number) => {
  return randomBytes(length).toString('hex').slice(0, length)
}

const encodeBase64 = (buffer: Buffer | ArrayBuffer): string => {
  return Buffer.from(buffer).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

export class CursorAutomation {
  private browser!: Browser
  private page!: Page
  private token!: string
  private client: AxiosInstance

  constructor() {
    this.client = axios.create({
      baseURL: 'https://api2.cursor.sh',
      headers: {
        origin: 'vscode-file://vscode-app',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Cursor/0.4.2 Chrome/108.0.5359.215 Electron/22.3.10 Safari/537.36'
      }
    })
  }

  private async digest(s: string): Promise<ArrayBuffer> {
    const hash = createHash('sha256')
    return hash.update(s, 'utf8').digest().buffer
  }

  async init() {
    try {
      this.browser = await puppeteer.launch({ 
        headless: false,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-gpu',
          '--disable-gpu-compositing',
          '--disable-webgl',
          '--enable-unsafe-swiftshader',
          '--window-size=1920,1080'
        ],
        ignoreDefaultArgs: ['--enable-automation'],
        defaultViewport: null
      })

      this.page = await this.browser.newPage()
      await this.page.setDefaultTimeout(30000)
      await this.page.setDefaultNavigationTimeout(30000)

      this.page.on('console', msg => {
        const type = msg.type()
        if (type === 'error' || type === 'warn') {
          console.log(`PAGE ${type.toUpperCase()}:`, msg.text())
        }
      })
      this.page.on('pageerror', err => console.error('PAGE ERROR:', err))

      await this.page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36')

      return true
    } catch (error) {
      console.error('Browser initialization error:', error)
      throw error
    }
  }

  async register() {
    try {
      console.log('Navigating to cursor.so...')
      await this.page.goto('https://cursor.so', { 
        waitUntil: 'networkidle0',
        timeout: 60000 
      })

      console.log('Waiting for page to load...')
      await this.page.waitForSelector('body', { visible: true })

      console.log('Looking for sign up button...')
      const buttons = await this.page.$$eval('button, a[role="button"], a', elements => {
        return elements.map(el => ({
          text: el.textContent?.trim() || '',
          tag: el.tagName.toLowerCase(),
          href: el instanceof HTMLAnchorElement ? el.href : '',
          classes: el.className,
          id: el.id,
          type: el.getAttribute('type') || '',
          role: el.getAttribute('role') || ''
        }))
      })
      console.log('Found buttons:', JSON.stringify(buttons, null, 2))

      console.log('Looking for form elements...')
      const inputs = await this.page.$$eval('input', elements => {
        return elements.map(el => ({
          type: el.type,
          id: el.id,
          name: el.name,
          classes: el.className,
          placeholder: el.placeholder
        }))
      })
      console.log('Found inputs:', JSON.stringify(inputs, null, 2))

      const email = `${randomStr(12)}@outlook.com`
      const password = randomStr(16)

      console.log('Trying to find email input...')
      const emailInput = await this.page.$('input[type="email"], input[name="email"]')
      if (!emailInput) {
        console.log('Taking screenshot of current page state...')
        await this.page.screenshot({ path: 'page-state.png', fullPage: true })
        throw new Error('Email input not found')
      }

      console.log('Typing email...')
      await emailInput.type(email, { delay: 50 })

      console.log('Trying to find password input...')
      const passwordInput = await this.page.$('input[type="password"], input[name="password"]')
      if (!passwordInput) {
        console.log('Taking screenshot of current page state...')
        await this.page.screenshot({ path: 'password-input-error.png', fullPage: true })
        throw new Error('Password input not found')
      }

      console.log('Typing password...')
      await passwordInput.type(password, { delay: 50 })

      console.log('Looking for submit button...')
      const submitButton = await this.page.$('button[type="submit"], button:has-text("Sign up"), button:has-text("Register")')
      if (!submitButton) {
        console.log('Taking screenshot of current page state...')
        await this.page.screenshot({ path: 'submit-button-error.png', fullPage: true })
        throw new Error('Submit button not found')
      }

      console.log('Submitting registration...')
      await Promise.all([
        this.page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 30000 }),
        submitButton.click()
      ])

      console.log('Registration completed, generating token...')
      await this.generateToken()

      return { email, password }
    } catch (error) {
      console.error('Registration error:', error)
      await this.page.screenshot({ path: 'error.png', fullPage: true })
      throw error
    }
  }

  private async generateToken() {
    try {
      const uuid = uuidv4()
      const randomBytesBuffer = randomBytes(32)
      const verifier = encodeBase64(randomBytesBuffer)
      const challenge = encodeBase64(Buffer.from(new Uint8Array(await this.digest(verifier))))

      const loginUrl = `https://cursor.so/loginDeepControl?challenge=${challenge}&uuid=${uuid}&mode=login`
      await this.page.goto(loginUrl, { waitUntil: 'networkidle0' })

      const tokenPath = `/auth/poll?uuid=${uuid}&verifier=${verifier}`
      
      for (let i = 0; i < 20; i++) {
        try {
          const response = await this.client.get(tokenPath)
          if (response.data?.accessToken) {
            this.token = response.data.accessToken
            return this.token
          }
        } catch (e) {
          await new Promise(resolve => setTimeout(resolve, 1000))
        }
      }
      throw new Error('Failed to get token')
    } catch (error) {
      console.error('Token generation error:', error)
      await this.page.screenshot({ path: 'token-error.png' })
      throw error
    }
  }

  async close() {
    await this.browser.close()
  }

  public getAccessToken() {
    return this.token
  }
}

async function main() {
  const cursor = new CursorAutomation()
  await cursor.init()
  
  try {
    const credentials = await cursor.register()
    console.log('Registration successful')
    console.log('Email:', credentials.email)
    console.log('Password:', credentials.password)
    console.log('Token:', cursor.getAccessToken())
  } catch (error) {
    console.error('Error:', error)
  } finally {
    await cursor.close()
  }
}

if (require.main === module) {
  main()
} 