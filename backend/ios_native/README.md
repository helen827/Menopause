# iOS 原生登录页

这里是 SwiftUI 原生版本的登录入口，对应本地 Tornado 接口：

- `POST /api/send_code`
- `POST /api/login`

## 使用方式

1. 在 Xcode 新建一个 iOS App，Interface 选择 `SwiftUI`。
2. 把 `MenocalmLogin/` 里的 `.swift` 文件拖进项目。
3. 如果你的 App 入口还是默认的 `ContentView()`，现在也可以正常显示，因为 `ContentView.swift` 会包装 `LoginView()`。
4. 如果跑 iOS Simulator，本地接口地址可以用默认的 `http://127.0.0.1:8888`。
5. 如果跑真机，把 `AuthAPI.baseURL` 改成 Mac 的局域网 IP，例如 `http://192.168.1.10:8888`。

如果使用 HTTP 调试接口，需要在 iOS 项目的 `Info.plist` 里允许本地开发请求，或改成 HTTPS。

## 已有 Xcode 项目接入

如果你已经有 `menopause_xiaApp.swift` 这种入口文件，不要再添加第二个 `@main`。

推荐做法：

1. 拖入 `AuthAPI.swift`、`ContentView.swift`、`LoginView.swift`、`LoginViewModel.swift`。
2. 不需要 `MenocalmLoginApp.swift`，本目录已经移除了这个示例入口，避免和你的 `menopause_xiaApp.swift` 冲突。
3. 把你现有的 `menopause_xiaApp.swift` 改成：

```swift
import SwiftUI

@main
struct menopause_xiaApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
```

不要只粘贴下面这一段到文件顶层：

```swift
WindowGroup {
    LoginView()
}
```

如果你不想改 `menopause_xiaApp.swift`，也可以让它保持：

```swift
WindowGroup {
    ContentView()
}
```

但必须保证新拖入的 `ContentView.swift` 已经加入当前 App target。
