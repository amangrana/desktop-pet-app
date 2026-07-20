# Desktop Pet Prototype 0.1

这是桌面宠物项目的第一个 Windows 技术原型。它使用 Godot 4.7.1 和 GDScript，已包含专注计时与基础健康提醒，但不包含 AI、养成或 Steam 功能。当前宠物是黑色巴哥犬 **Leo**、英国长毛猫 **Bobo**、金黄色巴哥犬 **Milo**，以及蓝眼灰面罩的西伯利亚森林猫 **Mable**。

## 项目目录

唯一主工作目录：`the project root (this repository)`

`an earlier export snapshot folder (outside this repo)` 只是早期导出快照，不参与后续开发或同步。运行、修改和测试都应在主工作目录进行。

![第一只宠物 Leo](assets/pets/leo/leo-master.png)

![第二只宠物 Bobo](assets/pets/bobo/bobo-master.png)

![第三只宠物 Milo](assets/pets/milo/milo-master.png)

![第四只宠物 Mable](assets/pets/mable/mable-master.png)

## 已实现

- 透明、无边框窗口
- 始终置顶开关
- 拖动并保存窗口位置
- 75%–300% 显示比例；宠物右键菜单字体、行距和留白同步缩放
- 宠物区域接收鼠标，其他透明区域穿透
- 以用户参考照片为原型创作的黑色巴哥犬 Leo 母版，采用与 Bobo 统一的简洁卡通色块和柔和阴影；黑色四肢与银灰眼周在小尺寸下保持清晰
- 以用户参考照片为原型创作的英国长毛猫 Bobo 母版
- 将早期金黄色巴哥犬原型完整保留为第三只宠物 Milo
- 以用户提供的真实照片为原型创作蓝眼西伯利亚森林猫 Mable 母版，以较大的圆眼和柔和面罩呈现友善卡通表情
- Leo 的待机呼吸、偶发摆动、键盘、鼠标和点击反应
- 自动发现 `assets/pets/*/pet.tres` 宠物包
- 右键菜单切换宠物，并在重启后恢复选择
- 宠物可以分别配置尺寸、点击轮廓、动作替代图和点击特效
- 缺少点击、键盘或鼠标动作图时自动回退到待机图
- 为动作特效预留安全边距，并防止窗口被拖到显示器可见区域之外
- 默认关闭、可暂停的匿名活动管线
- 每 100ms 聚合一次键盘/鼠标活动，避免高频事件形成动画队列
- 当前会话的键盘与鼠标分项计数，以及清除入口
- 独立 Windows Raw Input helper；游戏失去焦点时仍可接收键盘和鼠标按钮活动
- 启用时启动 helper，暂停或退出时终止，父进程异常退出后 helper 也会自动结束
- 内部自动化测试使用模拟批次验证计数与宠物动作；正式菜单不显示模拟入口
- 断开显示器后将窗口恢复到可见区域
- 25 分钟专注和 5 分钟休息计时
- 计时暂停、继续、取消和菜单倒计时
- 使用真实结束时间恢复运行中或暂停中的计时，兼容游戏重启和电脑睡眠
- 专注完成或休息完成时显示宠物气泡和高优先级提醒动作
- 专注运行时减少随机待机动作；开发环境提供 1 秒测试计时
- 两层右键菜单；顶层保持紧凑并实时显示当前专注或休息状态
- 默认关闭、可独立启用的喝水与站立活动提醒
- 健康提醒支持完成、按当前设置延后、跳过本次、暂停今天和关闭此类提醒，并按真实时间跨重启恢复
- 独立双语弹窗可一次设置专注、休息、喝水、站立和延后的默认分钟数；可一键恢复 25 / 5 / 60 / 45 / 10 分钟，保存前只修改表单，运行中的计时不会被重置
- 每日勿扰时段可选择关闭、22:00–08:00、23:00–08:00 或 00:00–08:00
- 专注期间暂存已到期的健康提醒，在休息开始后再用宠物动作和气泡提示
- 健康提醒气泡可直接点击完成、延后或打开更多操作；气泡收起后点击宠物可重新打开
- 可选的“宠物小纸条 / Pet Notes”会在非专注、非勿扰且没有待处理提醒时显示在宠物图片上；`OK` 按钮显示关闭倒计时，也可手动关闭
- 菜单、宠物气泡和系统对话框支持 English / 简体中文，并保存语言选择

## 活动感应与隐私

Windows 活动适配器已经接入。启用 `Activity sensing` 后，宠物在其他应用获得焦点时也会响应键盘按下和鼠标按钮按下。

活动感应默认关闭。用户第一次从菜单开启时会看到一次 Windows 原生隐私确认；确认开启后保存启用状态，以后启动自动恢复且不再重复提示。用户主动关闭后保持关闭，再次开启也不重复提示。

计数规则：

- 键盘：任意按下事件计数；松开不计数，长按产生的 Windows 自动连发会累计。
- 鼠标：左键、中键、右键、侧键 1 和侧键 2 的按下事件计数。
- 鼠标松开、移动和滚轮不计数。
- Godot 只收到 `keyboard_count` 和 `mouse_count`，不区分具体按键或按钮。

代码不会解析、暴露、记录或保存：

- 具体按键或输入文本
- 鼠标坐标
- 当前应用、窗口标题或进程
- 输入发生的时间序列

当前计数只保留在本次运行会话中；退出不会保存次数。

活动 helper 使用 Windows 自带的 .NET Framework 运行时，编译后的 x64 程序位于 `platform/windows/activity_helper/DesktopPetActivityHelper.exe`。重新编译时运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\platform\windows\activity_helper\build.ps1
```

任务栏 helper 只调用 Windows Shell 的 `ITaskbarList::DeleteTab`，不会修改窗口样式。重新编译时运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\platform\windows\taskbar_helper\build.ps1
```

凭据 helper 只允许读写 `DesktopPet.*` Generic Credential，refresh token 不通过命令行或临时文件传递。重新编译时运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\platform\windows\credential_helper\build.ps1
```

## 打开与运行

1. 安装或解压 [Godot 4.7.1 for Windows](https://godotengine.org/download/windows/)。
2. 启动 Godot。
3. 点击 **Import**，选择本目录的 `project.godot`。
4. 打开工程后按 `F6`/`F5` 或右上角运行按钮。

当前 Codex 工作区已经带有解压后的便携版 Godot，也可以在 PowerShell 中运行：

```powershell
# 直接运行宠物
.\launch.ps1

# 打开 Godot 编辑器
.\launch.ps1 -Editor
```

启动脚本优先使用主项目内被 Git 忽略的 `.tools/godot-4.7.1`，因此不依赖日期命名的 Codex 任务目录；如果本机 `PATH` 中已有 `godot` 或 `godot4`，也会自动使用它。

## 复制到另一台 PC

正式测试包位于 `dist\DesktopPet-Windows`。将整个目录复制到另一台 Windows 10/11 64 位 PC，保持主程序和三个 helper 在同一目录，然后运行 `DesktopPet.exe`；目标电脑不需要 Godot 或 `.tools`。源码开发方式仍可复制整个项目和 `.tools` 后使用 `launch.cmd`。

注意：

- 目标电脑需要支持 OpenGL 3.3 的显卡驱动。
- `.godot` 是可重建的导入缓存，即使没有复制，首次启动也会重新生成。
- 窗口位置、缩放、置顶、活动感应和计时状态保存在每台电脑自己的用户目录中，不会随项目文件夹复制。
- 这是开发原型的便携运行方式。面向普通玩家或 Steam 发布时，会导出独立的游戏 `.exe` 和资源包，不会附带 Godot 编辑器。

## 操作

- 左键拖动宠物：移动窗口
- 左键短按宠物：普通互动
- 左键短按 Leo、Bobo、Milo 或 Mable 的任一前爪：开始 25 分钟专注
- 从任一前爪拖动：仍然移动宠物，不会误触专注
- 宠物可以拖到屏幕可用区域边缘；透明窗口留白不再形成额外距离
- 右键宠物：打开独立的快捷菜单
- 顶层 `Focus — ...`：实时显示计时状态，并打开专注操作子菜单
- `Pets` 子菜单：切换当前宠物
- `Activity` 子菜单中的 `Activity sensing`：启用或暂停真实 Windows 活动感应
- `Activity source`：显示 Windows helper 的启动或运行状态
- `Session activity`：查看本次运行的键盘和鼠标计数
- `Clear session activity`：清除本次运行的计数
- `Start focus — 25 min`：开始专注计时
- `Start break — 5 min`：开始短休息
- `Pause timer` / `Resume timer`：暂停或继续当前计时
- `Cancel timer`：取消当前计时
- 专注结束后显示 5 秒倒计时，并自动开始休息
- `Cancel auto-start`：取消当前自动休息倒计时，保留“等待休息”状态
- 休息结束后等待用户确认，不会自动开始下一轮专注
- 顶层菜单或 `Focus` 子菜单保持打开时，当前阶段的 `MM:SS` 倒计时会实时刷新
- `Developer` 子菜单中的专注和休息 `1 sec (test)`：快速验证两种完成提醒；正式导出时整个子菜单隐藏
- `Window` 子菜单中的 `Always on top`：切换始终置顶
- `Window` 子菜单中的 `Scale`：切换宠物显示比例
- `Reminders` 子菜单：独立开启或关闭喝水与站立提醒，并实时查看下一次提醒倒计时
- `Settings` → `Set timer & reminder durations…`：打开独立窗口，一次设置 Focus、Break、Water、Stand 和 Snooze 的默认分钟数
- 保存的新时长从下一轮开始生效；已经运行中的专注、休息或健康提醒保留原截止时间
- `Quiet hours`：点击后在关闭和三个跨午夜预设之间切换；勿扰期间到期的提醒保持待处理，结束后再显示
- 健康提醒到点后可选择 `Complete`、`Snooze — 10 min`、`Skip`、`Pause ... today` 或关闭此类提醒
- 提醒气泡中的 `Done` / `10 min`：直接完成或延后当前提醒；`More` 提供跳过本次、今天暂停和关闭喝水/站立提醒
- `Done` 表示本次已完成，`Skip this time` 表示本次未完成但忽略；两者都会开始下一个正常周期。`Turn off ... reminders` 会停止该类周期，直到在 `Reminders` 菜单重新开启
- 提醒气泡自动收起后，左键短按宠物可再次打开当前待处理提醒
- `Developer` 子菜单中的喝水和站立 `1 sec (test)`：快速验证两种健康提醒；正式导出时隐藏
- `Settings` → `Language…`：打开独立语言选择窗口；首次安装跟随 Windows 系统语言，无法识别时回退 English；当前支持 English 和简体中文，选择会在重启后恢复
- `Settings` → `Pet Notes…`：设置非专注时的宠物小纸条，并连接、同步或断开用户自己的 Google Calendar
- Google Calendar 登录在系统浏览器完成，只申请日历列表与事件只读权限；同步层计划每 15 分钟刷新未来三天事件
- Google Calendar 使用 Desktop OAuth client、PKCE、随机 `state` 和 loopback 回调；该 Desktop client 的 token 交换要求其配套 client secret
- Godot 编辑器开发环境从项目根目录中被 Git 忽略的 `client_secret*.json` 加载配置；正式 Windows 导出通过插件把同一 Installed client 配置注入发行包，普通用户无需复制 JSON
- Google 明确说明 Installed/Desktop 应用无法保密，随应用提供的 client secret 不被视为机密；仓库仍不提交明文值，正式构建从本地 JSON 或 CI 进程环境变量读取，以减少误提交和自动扫描风险
- 时间、语言和 Pet Notes 设置窗口会随说明文字自动调整高度；内容超过屏幕可用空间时正文区域滚动，底部操作按钮始终保留在窗口内
- 宠物图片上的提醒和 Pet Note 对话气泡限制最大文本行数，过长内容以省略号裁切，不会把操作按钮挤出气泡
- refresh token 安全保存在当前 Windows 用户的凭据管理器中，重启后自动恢复登录；access token 仍只保存在进程内存。主动断开时会先持久禁止自动恢复，再删除已保存登录，因此立即退出也不会在下次启动重新连接
- `Developer` → `Pet Note — 10 sec (test)`：验证图片内小纸条、按钮倒计时和自动关闭
- 程序在 Windows 通知区域显示托盘图标；托盘菜单可显示/隐藏宠物、开始专注、打开 Pet Notes 或退出
- 程序提供 Windows 通知区域托盘入口；主宠物窗口通过 `ITaskbarList::DeleteTab` 隐藏任务栏按钮，不修改 Godot 窗口样式
- 宠物右键菜单保持无焦点窗口的稳定打开路径，并继续实时刷新计时状态；不得在菜单开关时切换透明主窗口焦点样式
- Windows 默认通过 ANGLE（Direct3D 11）运行 Compatibility renderer，避免部分 AMD 原生 OpenGL 驱动把透明窗口区域合成为黑色；ANGLE 不可用时回退到原生 OpenGL
- 自动化测试使用独立的 `user://` 设置文件，不得覆盖正式应用的计时、提醒或语言设置；旧版测试写入的 `40/8/75/35/15` 指纹会在启动时恢复为产品默认值并清除测试 reminder 状态
- 宠物显示比例同时调整右键主菜单、下级菜单和 reminder `More` 菜单的字体、行距与留白；Windows 原生托盘菜单继续由系统 DPI 控制
- 在菜单中点击 `Exit Desktop Pet`：退出

## 项目结构

```text
scenes/Main.tscn                  主场景
src/main.gd                       窗口、菜单、宠物切换和本地设置
src/Activity/activity_batch.gd    只含键盘/鼠标次数的匿名活动批次
src/Activity/activity_stats.gd    当前会话的聚合计数
src/Activity/input_activity_monitor.gd
                                  活动启停、100ms 聚合与统一事件出口
src/platform/windows/windows_activity_adapter.gd
                                  helper 进程、本地 UDP 和故障管理
src/platform/windows/windows_taskbar_adapter.gd
                                  只删除任务栏按钮的 Windows Shell 适配器
src/platform/windows/windows_credential_store.gd
                                  Windows 凭据 helper 会话与 OAuth 安全存取
src/timers/timer_manager.gd       专注/休息计时、暂停和真实时间恢复
src/timers/reminder_manager.gd    喝水/站立周期、延后、按日暂停和持久化
src/localization/app_localization.gd
                                  英语/简体中文用户界面词典与语言回退
src/checkins/check_in_manager.gd  小纸条队列、去重、过期、冷却与显示时长
src/checkins/calendar_check_in_source.gd
                                  定时/全天日历事件的小纸条触发
src/checkins/google_calendar_provider.gd
                                  Google Desktop OAuth、只读同步与事件标准化
src/checkins/google_oauth_client_config.gd
                                  OAuth 发行配置校验、固定 client ID 与注入路径
addons/google_oauth_export/       Windows 导出时注入 Installed client 配置
assets/ui/tray_icon.svg           Windows 通知区域托盘图标
platform/windows/activity_helper/ActivityHelper.cs
                                  Windows Raw Input helper 源码
platform/windows/activity_helper/DesktopPetActivityHelper.exe
                                  开发运行所需的 x64 helper
platform/windows/taskbar_helper/TaskbarHelper.cs
                                  ITaskbarList::DeleteTab helper 源码
platform/windows/taskbar_helper/DesktopPetTaskbarHelper.exe
                                  开发运行所需的 x64 任务栏 helper
platform/windows/credential_helper/CredentialHelper.cs
                                  Windows Credential Manager helper 源码
platform/windows/credential_helper/DesktopPetCredentialHelper.exe
                                  开发运行所需的 x64 凭据 helper
platform/windows/export_release.ps1
                                  注入 OAuth 配置并导出正式 Windows EXE
src/pets/pet_definition.gd        宠物资源格式
src/pets/pet_registry.gd          自动发现、校验和排序宠物包
src/pets/pet_visual.gd            所有宠物共用的显示与基础动作
assets/pets/leo/pet.tres          Leo 的宠物定义
assets/pets/leo/leo-master.png    Leo 的透明背景母版
assets/pets/bobo/pet.tres         Bobo 的宠物定义
assets/pets/bobo/bobo-master.png  Bobo 的透明背景母版
assets/pets/milo/pet.tres         Milo 的宠物定义
assets/pets/milo/milo-master.png  Milo 的透明背景母版
assets/pets/mable/pet.tres        Mable 的宠物定义
assets/pets/mable/mable-master.png Mable 的透明背景母版
launch.cmd                        可复制到其他 Windows PC 的便携启动入口
tests/activity_pipeline_test.gd   活动管线无界面自测
tests/windows_activity_adapter_test.gd
                                  helper 注册与内部匿名批次通信自测
tests/timer_manager_test.gd       计时状态与绝对时间恢复自测
tests/focus_timer_integration_test.gd
                                  菜单、持久化和完成气泡集成自测
tests/reminder_manager_test.gd    健康提醒周期、延后、暂停与恢复自测
tests/health_reminder_integration_test.gd
                                  健康提醒菜单、可点击气泡、语言与专注暂存集成自测
tests/localization_test.gd         本地化目录完整性、语言回退与格式化自测
tests/check_in_manager_test.gd     小纸条队列、过期与日历触发规则自测
tests/ambient_card_integration_test.gd
                                  图片内小纸条、倒计时、关闭与专注抑制集成自测
tests/google_calendar_provider_test.gd
                                  PKCE、回调解析、时区与 Google 事件标准化自测
tests/windows_credential_store_test.gd
                                  一次性假 token 的安全写入、读取和删除自测
tests/google_calendar_disconnect_policy_test.gd
                                  主动断连、立即重启与重新授权策略自测
tests/system_tray_integration_test.gd
                                  任务栏隐藏、托盘菜单和显示/隐藏行为自测
tests/windows_transparency_configuration_test.gd
                                  Windows 透明窗口与 ANGLE 回退配置自测
tests/google_oauth_packaged_config_test.gd
                                  对导出包内 OAuth 注入配置做黑盒自检
```

## 添加新宠物

普通新宠物不需要修改 `main.gd`、场景或通用动画代码：

1. 在 `assets/pets` 下创建以宠物 ID 命名的文件夹。
2. 放入透明 PNG 素材。
3. 创建 `pet.tres`，填写 `pet_id`、`display_name`、`idle_texture`、显示尺寸和点击轮廓。
4. 可选加入 `click_texture`、`keyboard_texture` 和 `mouse_texture`；没有提供的动作会使用 `idle_texture`。
5. 重新打开或运行项目，宠物会自动出现在右键菜单中。

完整字段和验收要求见 `docs/宠物资源包规范.md`。

## 导出带 Google Calendar 的 Windows 版本

1. 为 Godot 4.7.1 安装版本完全一致的 Windows export templates。
2. 将 Installed/Desktop OAuth JSON 保留为项目根目录下被 Git 忽略的 `client_secret*.json`。
3. 运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\platform\windows\export_release.ps1
```

脚本会校验固定 client ID，通过进程环境把 client 配置交给 Godot 导出插件，并清理后重建 `dist\DesktopPet-Windows` 中的 `DesktopPet.exe`、`DesktopPetActivityHelper.exe`、`DesktopPetCredentialHelper.exe` 和 `DesktopPetTaskbarHelper.exe`。四个 EXE 必须一起分发并放在同一目录。测试 PCK 位于独立的 `dist\tests`，不会混入正式包。原始 JSON 不会进入发行包；插件只加入运行所需的规范化 `client_id` 与 `client_secret`。CI 可改用 `DESKTOP_PET_GOOGLE_CLIENT_ID` 和 `DESKTOP_PET_GOOGLE_CLIENT_SECRET` 两个受保护环境变量，不需要创建 JSON。

如果发行配置缺失或 client ID 不匹配，应用会在打开浏览器前显示配置错误。不要把 Desktop client secret 当作用户数据或访问令牌：它随 Installed 应用分发且可被提取；真正能访问个人日历的是每位用户授权后生成并保存于其 Windows 凭据管理器中的 refresh token。

## 当前原型的已知限制

- 只面向 Windows 11 验证。
- 当前包含 Leo、Bobo、Milo 和 Mable 四个正式宠物包。
- Windows 活动 helper 当前只构建为 x64。
- 真实键鼠活动仍需要在不同键盘、鼠标和长时间运行场景下继续实机验收。
- 番茄钟支持自定义专注和休息默认分钟数；尚无自动连续阶段、声音或专注历史。
- 健康提醒支持自定义喝水、站立和延后分钟数以及勿扰时段；尚无声音、Windows 系统通知或完整的多分类设置页。
- 宠物小纸条已完成 Google Calendar OAuth、只读同步和 Windows Credential Manager 持久登录；编辑器使用被 Git 忽略的本地 JSON，正式 Windows 发行包在导出阶段注入 Desktop client 配置。公开发布前仍需完成 Google OAuth 应用验证，并在独立电脑上验收导出包登录。
- 当前只提供 English 和简体中文；宠物名称仍使用宠物包中定义的专名。
- 鼠标穿透区域是简化多边形，不是逐像素轮廓。
- 系统托盘第一阶段已完成；完整的计时与待处理提醒“活动托盘”仍未实现。
- 独占全屏应用可能覆盖置顶窗口。
- 每个新宠物包都需要配置能覆盖动作和特效的点击轮廓。
