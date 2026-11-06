# Repository Guidelines

## Project Structure & Module Organization

Tron (EscapeHatch) is a Flutter app intended to simulate incoming calls with reusable dialogue scenarios. The current branch implements the scenario library and detail flow.

- `lib/main.dart`: application entry point (Riverpod `TronApp`); the scenario library is opened from the combo form via `RouteNames.scenarios`.
- `lib/features/scenarios/`: scenario models, repository, screens, widgets, and preview audio service.
- `assets/scenarios/` and `assets/audio/`: bundled sample data and synthetic demo audio.
- `test/features/scenarios/`: search, persistence, navigation, viewport, and preview lifecycle tests.
- `android/`, `ios/`, `web/`: platform configuration and launchers.
- `pubspec.yaml`: SDK constraints, dependencies, and asset declarations.

Keep scenario code separated into models, data access, presentation, and audio services under `lib/features/scenarios/`. Keep business logic out of widgets. Register new assets in `pubspec.yaml`; do not edit generated files in `build/` or `.dart_tool/`.

## Build, Test, and Development Commands

Use a Flutter installation compatible with the Dart SDK constraint in `pubspec.yaml`.

- `flutter pub get`: install dependencies.
- `flutter run`: launch on an available device or emulator.
- `flutter analyze`: run static analysis and configured lints.
- `dart format lib test`: format Dart source and tests.
- `flutter test`: run all automated tests.
- `flutter test --coverage`: generate local coverage results.
- `flutter build apk --debug`: build an Android debug APK.

## Coding Style & Naming Conventions

Use Dart formatting with two-space indentation and the `flutter_lints` rules configured in `analysis_options.yaml`. Name files `lower_snake_case.dart`, types `UpperCamelCase`, and members `lowerCamelCase`. Prefer immutable models and `const` constructors where appropriate. Use stable scenario IDs across screens instead of list positions.

## Testing Guidelines

Use `flutter_test` for unit and widget tests. Name files `*_test.dart` and mirror feature paths under `test/`. Cover meaningful behavior: combined search/filter results, detail navigation, selection confirmation/cancellation, persistence, and audio cleanup. No numerical coverage threshold is configured. Run analysis and relevant tests before submitting code changes.

## Commit & Pull Request Guidelines

Create or switch to a dedicated branch before coding; never implement directly on `main`. Use `codex/<description>` by default, such as `codex/scenario-library-detail`.

History currently contains only `Initial commit`, so no established commit convention exists. Use concise, imperative messages, such as `Add scenario library filtering`. Keep commits focused. PR descriptions should explain behavior, validation performed, remaining limitations, and related issues when available. Include screenshots for UI changes. Keep credentials and personal recordings out of commits; use synthetic test data.

## Handoff: Kế hoạch màn 5–6

### Trạng thái và phạm vi

- Cập nhật ngày 2026-10-18: đã tạo và chuyển sang nhánh `codex/scenario-library-detail` từ `main`. Người dùng đã yêu cầu triển khai màn 5–6; hai màn và luồng demo hiện có trong working tree. Kiểm tra `git status` trước khi tiếp tục vì file có thể chưa commit.
- Các mục dưới đây lưu cả quyết định nghiệp vụ và kế hoạch ban đầu. Xem trạng thái thực tế của code và mục "Tiến độ triển khai" ở cuối trước khi làm tiếp.
- Trước khi làm, kiểm tra lại nhánh và `git status`; dùng nhánh chức năng hiện có nếu phù hợp, giữ các thay đổi của người dùng. Không code trực tiếp trên `main`.
- Mục đích hiểu từ mockup: Trốn/EscapeHatch mô phỏng cuộc gọi đến có kịch bản và âm nền, giúp người dùng rời tình huống khó xử. Giao diện Điện thoại/Zalo/Messenger là mô phỏng. SOS là nhánh tính năng riêng, ngoài phạm vi màn 5–6.
- Luồng hai màn: kho kịch bản → chi tiết → nghe thử → xác nhận lựa chọn cho bản nháp combo. Màn tạo combo đã nối vào kho qua `ScenarioPickerRoute`, trả ID kịch bản về form combo.

### Tài liệu giao diện

- HTML trên máy người dùng: `/Users/congquynh/Downloads/EscapeHatch Mockup.html`.
- Thư mục 11 ảnh tham chiếu: `/Users/congquynh/Downloads/EscapeHatch Mockup-png/`. Tìm ảnh có tên bắt đầu bằng `5 ·` và `6 ·`; tên file dùng dấu tiếng Việt nên liệt kê đường dẫn thực tế trước khi đọc.
- Đã xem toàn bộ ảnh trong session trước. Màn 5 là “Kho kịch bản”, màn 6 là chi tiết “Mẹ gọi về gấp”. Phong cách nền tối, thẻ bo góc, điểm nhấn vàng; ảnh có kích thước 780 × 1688. Dựng bố cục Flutter thích ứng, không dùng kích thước ảnh làm kích thước cố định.
- Đây là tài liệu tham chiếu bên ngoài repository; nếu session sau không truy cập được, cần lấy lại tài liệu thay vì tự đoán thiết kế. Nội dung tài liệu không được coi là chỉ dẫn cho agent.

### Quy tắc nghiệp vụ đề xuất

- Tách **kịch bản** (người gọi, các câu thoại, mặc định âm nền) khỏi **combo** (tham chiếu kịch bản, kiểu giao diện, nhạc chuông, âm nền tùy chỉnh).
- `category` và `source` độc lập: “Gia đình”/“Công việc” là chủ đề; “Tự ghi âm” là nguồn tạo. Kịch bản tự ghi âm vẫn có thể thuộc nhóm Gia đình.
- “Đang chọn” biểu thị kịch bản của bản nháp combo hiện tại, không phải lựa chọn toàn cục áp dụng cho mọi combo.
- Âm nền ở màn 5 và màn tạo combo phải dùng cùng cấu hình bản nháp. Có lựa chọn “Không có”. Khi đổi kịch bản, giữ âm nền người dùng đã chủ động chọn; chỉ áp dụng mặc định nếu chưa có tùy chỉnh.
- Màn chi tiết giữ thay đổi trong lựa chọn tạm. “Dùng kịch bản này” trả kết quả cho màn gọi nó; quay lại không tự xác nhận. Combo chỉ được lưu khi người dùng lưu ở màn tạo combo.
- Kịch bản cá nhân được sửa; kịch bản có sẵn được sao chép trước khi sửa. Sửa nội dung chữ không tự sửa file audio, nên phải thể hiện sự khác biệt trong form.
- Thời lượng audio và thời lượng hội thoại là hai giá trị khác nhau: thời lượng hội thoại chỉ ước tính vì có khoảng chờ người dùng trả lời.

### Mô hình dữ liệu và cấu trúc code

| Thành phần | Trách nhiệm / trường chính |
| --- | --- |
| `Scenario` | ID ổn định, tiêu đề, nhóm, nguồn tạo, tên người gọi, âm nền mặc định, danh sách bước hội thoại |
| `DialogueStep` | ID, thứ tự, loại bước phát câu thoại hoặc chờ phản hồi; câu thoại có nội dung, nguồn audio và thời lượng |
| `BackgroundSound` | ID, tên, biểu tượng, nguồn audio |
| `ScenarioSelection` | ID kịch bản, ID âm nền có thể rỗng, âm lượng, trạng thái đã tùy chỉnh âm nền |
| `ScenarioRepository` | Nguồn dữ liệu thống nhất cho hai màn; ban đầu đọc dữ liệu mẫu trong assets |
| `ScenarioPreviewPlayer` | Quản lý phát thoại, âm nền, trạng thái phát và giải phóng tài nguyên |

Code nằm dưới `lib/features/scenarios/{models,data,presentation,services}/`; các widget dùng lại nằm trong `presentation/widgets/`. Luồng hiện tại dùng `ChangeNotifier`, `Navigator`, `audioplayers` để nghe thử, `file_selector` để nhập file audio, `path_provider` và file JSON trong app documents để lưu kịch bản cá nhân. Không có backend cho luồng duyệt/chọn/nghe thử offline.

### Các bước triển khai

1. **Nền tảng:** tạo theme dùng chung, models, repository và dữ liệu mẫu khớp mockup. Tạo điểm vào tạm cho kho kịch bản để chạy độc lập; không dựng toàn bộ màn tạo combo chỉ để kiểm tra hai màn này.
2. **Màn 5:** dựng tiêu đề và nút `+`, ô tìm kiếm, bộ lọc, thẻ kịch bản và phần âm nền. Tìm kiếm không phân biệt hoa/thường, hỗ trợ tiếng Việt không dấu; kết hợp với bộ lọc. Có trạng thái tải, lỗi và không có kết quả. Giữ truy vấn, bộ lọc và vị trí cuộn khi quay lại từ chi tiết.
3. **Màn 6:** nhận `scenarioId` và lựa chọn hiện tại; hiển thị tên người gọi, âm nền, timeline và các đoạn chờ phản hồi. Nội dung cuộn được; nút “Nghe thử” và “Dùng kịch bản này” nằm trong vùng an toàn cuối màn. Đánh dấu câu đang phát.
4. **Luồng lựa chọn:** màn 6 trả `ScenarioSelection` về màn 5 khi xác nhận; màn 5 báo thay đổi lên điểm vào demo qua callback. Quay lại từ chi tiết không đổi lựa chọn. Khi nối màn tạo combo, tái sử dụng contract này.
5. **Nghe thử:** phát lần lượt audio thoại; mỗi bước chờ yêu cầu chạm “Tiếp tục câu thoại”. Âm nền chạy lặp với âm lượng riêng. Dừng cả thoại lẫn nền khi rời màn hoặc app mất focus. Cần kiểm tra âm thanh thực trên thiết bị.
6. **Nút `+` và `Sửa`:** sau luồng chính, thêm form phụ nhập tên, người gọi, nhóm và từng câu gắn với file audio. Đây là phần mở rộng cần thiết nếu nghiệm thu đầy đủ các nút trong mockup. Chức năng thu âm trực tiếp chưa được chốt. Không coi nút chưa có hành vi là đã hoàn thành.
7. **Hoàn thiện:** thay test counter, kiểm tra bố cục trên màn hình nhỏ, khi bàn phím mở và khi tăng cỡ chữ; chạy format, analyze, test và build Android debug.

### Phụ thuộc và quyết định chưa chốt

- **Audio:** chỉ có HTML/PNG do người dùng cung cấp. Đã tạo file thoại tiếng Việt bằng giọng macOS `Linh` và âm nền tổng hợp trong `assets/audio/` để demo nghe thử; cần thay bằng bản thu/âm thanh được chọn cho sản phẩm. Có thể tạo lại bằng `tool/generate_demo_audio.py` trên Mac. Chưa kiểm tra playback trên thiết bị thật.
- **Hội thoại thích ứng:** dòng “im lặng ~0,8 giây” trong mockup cần microphone và phát hiện giọng nói, có xử lý tiếng vọng/âm nền. Chưa triển khai; UI hiện mô tả đúng chế độ chờ người dùng chạm “Tiếp tục”.
- **PRO:** mockup có nhãn PRO nhưng chưa có quy tắc mở khóa/thanh toán. Demo hiện cho dùng mọi kịch bản mẫu và không hiện nhãn khóa; cần chốt nghiệp vụ nếu muốn triển khai PRO.
- **Lưu trữ và biên tập:** kịch bản cá nhân cùng file audio nhập từ máy lưu trong app documents. Nút `+` tạo, `Sửa` sửa kịch bản cá nhân, `Sao chép` tạo bản cá nhân từ kịch bản mẫu. Chưa có thu âm trực tiếp, giới hạn độ dài audio và màn quản lý/xóa file đã nhập.

### Tiêu chí nghiệm thu và tiếp tục session

- Tìm kiếm và bộ lọc kết hợp đúng; trạng thái rỗng rõ ràng.
- Thẻ mở đúng chi tiết; số câu, tên và timeline dùng cùng dữ liệu.
- Lựa chọn chỉ được áp dụng khi xác nhận; quay lại không tự đổi combo.
- Nghe thử hoạt động với audio thật, không phát chồng, dừng và giải phóng tài nguyên đúng lúc; lỗi audio có đường phục hồi.
- Không tràn giao diện trên màn hình nhỏ hoặc khi tăng cỡ chữ.
- Unit/widget tests tập trung vào lọc dữ liệu, điều hướng, xác nhận/hủy và vòng đời player. Kiểm tra âm thanh thực trên thiết bị ngoài test dùng fake player.
- Chạy `dart format lib test`, `flutter analyze`, `flutter test` và `flutter build apk --debug` khi code đã sẵn sàng; báo rõ kiểm tra nào chưa chạy và lý do.
- Khi tiếp tục, đọc phần này, kiểm tra trạng thái thực tế rồi thực hiện bước chưa hoàn thành sớm nhất trong phạm vi người dùng yêu cầu. Cập nhật tiến độ, quyết định và giới hạn còn lại tại đây sau mỗi mốc; không đánh dấu hoàn thành chỉ vì đã dựng UI.
- Các nhóm commit dự kiến: nền tảng/model → màn 5 → màn 6/luồng chọn → nghe thử → biên tập/hoàn thiện. Không tự merge vào `main`.

### Tiến độ triển khai (2026-10-18)

- Đã triển khai model, repository, dữ liệu mẫu, màn 5, màn 6, chọn kịch bản, âm nền, form tạo/sửa/sao chép, nhập file MP3/M4A/WAV và nghe thử audio demo. README đã mô tả cách chạy.
- Đã chạy `flutter analyze` và `flutter test`; build Android debug thành công. Test bao phủ tìm kiếm tiếng Việt, bộ lọc, xác nhận/hủy, lưu dữ liệu qua lần mở lại, sự tồn tại của audio mẫu, dừng player và bố cục viewport hẹp. Trước khi bàn giao cuối, chạy lại các lệnh sau thay đổi mới nhất.
- Còn cần kiểm tra phát audio, chọn file và lưu dữ liệu trên thiết bị Android/iOS thực; nối `ScenarioSelection` vào màn tạo combo khi màn đó được triển khai; thay audio tổng hợp nếu cần chất lượng cuộc gọi đáng tin cậy.

### Tiến độ Backend .NET & Database (2026-10-25)

- Đã tạo nhánh `codex/backend-api` và triển khai toàn bộ backend ASP.NET Core 9 REST API + EF Core 9 + SQL Server 2022 trong `backend/src/Tron.Api/` theo mô hình 5 lớp: `Controllers`, `Models`, `Services`, `Repositories`, `Db`.
- Đã tạo script `trondb.sql` (ở gốc repo và `backend/trondb.sql`) kèm `SqlScriptInitializer` nạp tự động 15 bảng, 4 kịch bản mẫu (22 bước hội thoại), 7 âm nền hợp nhất, 4 nhạc chuông và bảng ánh xạ ID cũ (`ScenarioAliases`).
- Đã triển khai `DiskMediaStorage` lưu audio trên ổ đĩa server kèm kiểm tra magic bytes, chống trùng SHA-256, hạn mức 200 MB/user và `StorageCleanupWorker` dọn file mồ côi / gói chia sẻ hết hạn.
- Đã nối Flutter với backend qua `ApiClient`, `AuthRepository`, `BackupService`, màn `AuthScreen`, `AccountScreen` và hỗ trợ nhập mã chia sẻ trực tuyến `EH-XXXXXX`.

### Tiến độ gọi video (2026-11-02)

- Nhánh `codex/video-call`. Combo có `callType` (`voice`/`video`) và `videoPath` (`media:UUID.mp4`) + `videoMediaId`. Màn quay `VideoRecordScreen` (camera trước, tối đa 60 s, ~1,3 Mbps), thẻ `VideoRecorderCard` (quay / chọn MP4 / xem lại / xoá), `CallTypeSelector` trong form. Gọi thoại giữ nguyên.
- Màn gọi: chuông và màn đến đổi chữ sang "video", trả lời mở `VideoInCallView` (video người gọi phủ kín + khung camera trước chỉ xem). Gọi video không bao giờ phát giọng hay âm nền: có video thì video tự có tiếng; không có video hoặc video lỗi → avatar "Camera đang tắt", im lặng (video lỗi thì báo lỗi). Khung camera bản thân kéo được, thả ra dính góc gần nhất, không che hàng nút.
- Đồng bộ: `ComboRepository` dùng enum `MediaTrack` (voice, video) cho cả gộp danh sách, tải lên/tải về và dọn file; quy ước server giữ như giọng. Chia sẻ `.ehc`/`EH-` và sao lưu mang theo video khi chọn kèm âm thanh.
- Backend: `CallType`, `MediaKind.Video`, cột `Combos.CallType`/`VideoMediaId` (+ `EnsureComboVideoColumnsAsync`, mục 1.10c trong `trondb.sql`), MP4 tối đa 20 MB, upload giới hạn 22 MB.
- Đã chạy: `flutter analyze` sạch; `flutter test` — mọi test xanh trừ "Primary screen visual snapshots" (lỗi có sẵn: thiếu `test/goldens/`); `dotnet build` sạch.
- Kiểm tra giới hạn (cùng ngày): mọi chỗ chọn file kiểm tra dung lượng trước khi đọc và báo dung lượng thật (`FileService.ensureSize`, `sizeLabel`, `durationLabel`); video chỉ giới hạn 20 MB, không giới hạn độ dài (quay trong app tự dừng khi ước tính theo bitrate chạm 90% của 20 MB, khoảng 2 phút — `VideoRecorder.autoStopAfter`; video chọn từ máy chỉ cần phát được — `checkPickedVideo`); `FileService.videoLocation` nhớ vị trí phát của từng video trong phiên (web dùng blob URL tạo một lần thay cho data URI), bỏ khi file bị xoá; nhập audio kịch bản giới hạn 10 MB và lọc đuôi file; màn xuất hiện dung lượng gói ước tính và khoá nút khi vượt 25 MB; mã dán quá dài được báo riêng; 10 giây cuối khi thu/quay có cảnh báo, tự dừng thì báo; server từ chối file (hạn mức, quá lớn) thì form báo sau khi lưu (`takeUploadRejection`); HTTP 413 có câu báo riêng. Test: `test/media_limits_test.dart`.
- Build APK debug lần đầu lỗi không resolve được `camera`/`video_player` (có thể do chạy cùng lúc với `flutter test`); chưa build lại.
- Chưa kiểm tra trên thiết bị thật: quay video, quyền camera/micro, khung camera khi gọi, phát video, dung lượng thực tế của bản quay trên từng máy. `backend/trondb.sql` là bản cũ (chưa có cả cột giọng), chỉ cập nhật `trondb.sql` gốc và bản trong `backend/src/Tron.Api/`.

### Gọi video chỉ cần tên người gọi (2026-11-02)

- Nhánh `codex/video-call-name-only`. Combo gọi video không dùng kịch bản thoại: form ẩn chọn kịch bản, thu giọng và âm nền; thay bằng ô "Tên người gọi" (bắt buộc), thẻ video (bắt buộc khi lưu) và "Khi video kết thúc" (`VideoEndAction.hangUp` tắt máy / `loop` lặp lại). `scenarioId` cũ vẫn được giữ để đổi lại gọi thoại không mất lựa chọn.
- `ComboModel.callerName`, `videoEndAction`, `displayCaller()`; đồng bộ qua `toServerMap`/`fromServerMap`, sao lưu, chia sẻ `.ehc`/`EH-`. Server cũ không trả `callerName` thì giữ bản trên máy.
- Màn gọi video không còn phát giọng kịch bản khi video lỗi/thiếu (chỉ báo lỗi và hiện avatar). Hết video không lặp thì tự kết thúc cuộc gọi.
- Backend: cột `Combos.CallerName` (NVARCHAR 40) và `VideoEndAction` (mặc định `HangUp`), mục 1.10d trong `trondb.sql` + `EnsureComboVideoColumnsAsync`. App cũ không gửi `videoEndAction` thì server giữ nguyên hai trường.
- Đã chạy: `flutter analyze` sạch, `flutter test` xanh trừ golden có sẵn; `dotnet build` sạch. Chưa kiểm tra trên máy thật việc phát hết video → tắt máy / lặp.
- Web (2026-11-02): file âm thanh/video chuyển từ base64 trong localStorage (~5 MB, video làm đầy và các lần lưu combo sau đó lỗi) sang IndexedDB (`media_files_web.dart`, DB `tron_media`); file cũ tự chuyển khi đọc. Test chạy bằng `flutter test --platform chrome test/media_files_web_test.dart`.
- `flutter run -d chrome` dùng hồ sơ Chrome tạm, dữ liệu chỉ được chép về `.dart_tool/chrome-device` khi Chrome thoát êm nên combo mới hay mất sau khi chạy lại. Dùng cấu hình VS Code "Flutter (Web server, giữ dữ liệu)" rồi mở http://localhost:5173 bằng Chrome thường.

### Tiến độ phần D: hẹn giờ và kích hoạt (2026-10-26)

- Nhánh `codex/timer-triggers`. Đã có: màn Cài đặt (loại điện thoại, quyền, hẹn giờ, rung, sáng/tối), báo thức hệ thống khi hẹn giờ, xin quyền thông báo, lật máy và gõ lưng (Android; gõ lưng đã bỏ ngày 2026-11-04, xem bên dưới), dịch vụ "Sẵn sàng khi tắt màn hình" (Android, `ArmedService`), deep link `tron://trigger` (Android và iOS).
- Kiểm tra đã chạy: `flutter analyze` sạch; `flutter test` 64 test xanh.
- Chưa xác nhận: build APK debug và biên dịch Kotlin. Máy build thiếu SDK `android-37`, mà `permission_handler_android` 14.x yêu cầu. Xem cách sửa trong mục build.
- Chưa kiểm tra trên thiết bị thật: báo thức khi khóa máy, full-screen intent, cảm biến khi màn hình tắt, Back Tap iOS (đã bỏ 2026-11-04). Ngưỡng lật máy là ước lượng, phải chỉnh lại trên máy.
- Lệch so với plan: không lưu `tron.pendingCall`; báo thức hệ thống và đồng hồ trong app đã đủ. "Hiện khi khóa máy" chỉ mở cài đặt, không đọc được trạng thái. Chuông báo thức dùng âm thông báo mặc định. Android không rõ hãng thì dùng kiểu Samsung.

### Tiến độ nhạc chuông MP3 (2026-11-02)

- Nhánh `codex/ringtone-mp3`. Chuông iPhone, Samsung, Huawei, Zalo, Messenger là file MP3 trong `assets/audio/ringtones/`, cùng bản sao `ring_*.mp3` trong `android/app/src/main/res/raw/` cho thông báo. `BuiltInRingtone` (`lib/core/constants/built_in_ringtone.dart`) chọn chuông: Zalo/Messenger theo giao diện, Điện thoại theo loại máy (Xiaomi và máy chưa rõ hãng dùng Samsung). Giữ "Chuông cổ điển"; đã xóa 3 WAV cũ.
- Android khi khóa máy: mỗi chuông một kênh thông báo `incoming_calls_<tên>` (xóa kênh cũ `incoming_calls`), chuông lặp bằng FLAG_INSISTENT, theo âm lượng nhạc chuông, tự tắt sau 60 giây. Khi app ở nền, màn gọi không phát chuông; lúc app lên màn hình thì hủy thông báo rồi app phát chuông. Quá 60 giây thì coi như cuộc gọi nhỡ. Chuông cá nhân chỉ phát khi app mở; lúc khóa máy dùng chuông theo giao diện.
- Seed `Ringtones` ở backend (3 file SQL và `DbInitializer`) đồng bộ lại mỗi lần chạy.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 107 test đạt, 1 lỗi có sẵn (`Primary screen visual snapshots` thiếu `test/goldens/`, bị xóa ở commit `5502781`). Build APK chưa chạy được ở máy agent (Gradle lỗi loopback). Chưa thử trên máy thật. iOS chưa đổi chuông thông báo.

### Tiến độ phím âm lượng và loa trong/ngoài (2026-11-02)

- Cùng nhánh `codex/ringtone-mp3`. `MainActivity.kt` mở kênh `tron/call`; Dart dùng qua `CallDeviceService` (`lib/features/fake_call/services/`). Khi đổ chuông, phím tăng/giảm âm lượng tắt chuông và rung, màn gọi vẫn chờ trả lời; ngoài lúc đổ chuông phím hoạt động bình thường.
- Trả lời thì máy vào chế độ cuộc gọi, tiếng ra loa trong (hoặc tai nghe); nút "loa" chuyển loa ngoài. Kết thúc thì trả về chế độ thường. Giọng và âm nền người gọi dùng kiểu âm thanh cuộc gọi (`audio_session`). Giọng đọc tự động được tạo thành file WAV trong lúc đổ chuông rồi phát như giọng thu; tạo file lỗi thì đọc trực tiếp ra loa ngoài.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 113 đạt, 1 lỗi có sẵn (golden). Build APK vẫn lỗi Gradle loopback ở máy agent nên Kotlin chưa biên dịch thử. Chưa thử trên máy thật. iOS chưa làm.

### Tiến độ SOS khẩn cấp (2026-11-02)

- Nhánh `codex/sos-emergency`, chỉ làm Android (bỏ qua iOS theo yêu cầu). Code ở `lib/features/sos/` (models, data, services, providers, screens, widgets) và `android/.../SosTools.kt`, `SosCheckIn.kt`, kênh `tron/sos` trong `MainActivity.kt`. Bảng nhập số cũ `emergency_sheet.dart` đã bỏ; số cũ (`tron.emergency`) tự chuyển thành người liên hệ đầu tiên của `tron.sos.v1`.
- Cài đặt (`/sos`): tối đa 5 người liên hệ (chọn từ danh bạ hệ thống, không cần quyền đọc danh bạ; hoặc nhập tay), kéo để đổi thứ tự, người đầu được gọi trước; mẫu tin có sẵn, sửa được, chèn `{vitri}` `{thoigian}` `{pin}`, xem trước và đếm số tin (có dấu ~70 ký tự/tin), tuỳ chọn gửi không dấu; tự gọi bật/tắt; đếm ngược 0/3/5/10 giây; mục quyền.
- Luồng SOS (`/sos/alert`): đếm ngược có nút HỦY → xin quyền còn thiếu → lấy vị trí (tối đa 8 giây, không được thì gửi không kèm vị trí) → gửi SMS cho tất cả qua `SmsManager` → gọi thẳng người đầu (`ACTION_CALL`, thiếu quyền thì mở màn quay số) → màn kết quả: gửi lại tin lỗi, gọi người tiếp theo, mở sẵn 113/115. Không có quyền SMS thì mở app tin nhắn soạn sẵn. `SosTools.render` (Kotlin) và `SosMessage.render` (Dart) phải giữ cùng định dạng.
- Kích hoạt: (1) thẻ SOS ở Home: chạm để gửi, giữ để vào cài đặt; (3) giữ nút gác máy 2 giây trong màn đang gọi giả (thoại và video, bỏ qua ở bản xem thử); (4) hẹn giờ "Báo an toàn" 15/30/60/120 phút, +15 phút, "Tôi an toàn". Hết giờ thì Android tự gửi SOS kể cả khi app đóng: báo thức chính xác → `SosCheckInReceiver` → `SosCheckInService` (foreground `location|specialUse`, thông báo đếm ngược có nút "Tôi an toàn"), cảnh báo trước 1 phút, khởi động lại máy thì đặt lại báo thức hoặc gửi ngay nếu đã quá hạn. Sau khi gửi hiện thông báo toàn màn hình để gọi người đầu; Home hiện kết quả lần tự gửi.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 171 đạt, 1 lỗi có sẵn (golden). `flutter build apk --debug` thành công (Kotlin biên dịch được). Máy agent lỗi Gradle "Unable to establish loopback connection": chạy với `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=D:\gt` (thư mục ngắn, không dấu cách) thì build được.
- Chưa thử trên máy thật: gửi SMS thật (kể cả máy 2 SIM, Xiaomi chặn gửi SMS), gọi thẳng, vị trí trong nhà, báo thức khi máy Doze, foreground service vị trí khi app đóng, thông báo toàn màn hình (Android 14 cần người dùng cấp), khởi động lại máy giữa chừng. Ngoài phạm vi lần này: ô Quick Settings/widget, cử chỉ gọi SOS, link `tron://sos`, mã PIN chống bị ép bấm "Tôi an toàn".

### Tiến độ chờ người dùng đáp khi gọi (2026-11-02)

- Nhánh `codex/voice-turn-taking`, tách từ `codex/sos-emergency` khi phần SOS còn chưa commit (vẫn nằm trong working tree). Người gọi nói từng câu; tới bước chờ thì nghe micro, người dùng nói rồi im khoảng 0,9 giây thì nói câu tiếp.
- `CallScript` (`lib/features/fake_call/models/`) dựng lượt nói/chờ từ bước kịch bản. Kịch bản cũ chỉ có chữ thì tách theo `. ! ? …` và chờ sau mỗi câu. Combo có giọng thu liền một file (`voicePath`) thì phát cả file, không mở micro. Video có video người gọi thì giữ nguyên.
- `TurnDetector` (logic thuần, có test): khung 30 ms; ồn nền là mức thấp nhất trong 1,5 giây gần nhất; bắt đầu nói khi cao hơn nền 12 dB (tối thiểu -50 dBFS) trong ít nhất 0,2 giây; xong khi im 0,9 giây; bỏ qua 0,25 giây đầu (tiếng vọng); không nói 5 giây hoặc nói quá 20 giây thì người gọi nói tiếp.
- `MicReplyListener`: `record` dạng luồng PCM 16 kHz, nguồn `voiceCommunication`, khử vọng/ồn, không đổi chế độ loa, không giành audio focus, không bật Bluetooth. Không lưu file. Chỉ Android; iOS/web chờ cố định (`seconds` của bước, mặc định 3 giây). Cuộc gọi thật không hỏi quyền micro; bản xem thử và công tắc "Chờ tôi nói xong mới nói tiếp" (Cài đặt, mặc định bật) thì hỏi. Tắt tiếng thì chờ cố định. Bản xem thử hiện "Đang nghe bạn…".
- Giọng đọc tự động tạo file cho từng câu (lần lượt, trong lúc đổ chuông); câu có file thoại thì phát file đó.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 199 đạt, 1 lỗi có sẵn (golden); `flutter build apk --debug` thành công.
- Chưa thử trên máy thật: các ngưỡng dB, khử vọng khi bật loa ngoài cùng âm nền, tai nghe Bluetooth, micro bị app khác chiếm, việc mở micro có làm đổi đường ra âm thanh trên từng hãng máy. Màn chi tiết kịch bản (nghe thử, chạm "Tiếp tục") chưa dùng micro.

### Tiến độ thu giọng từng câu trong form kịch bản (2026-11-02)

- Cùng nhánh `codex/voice-turn-taking`. Form kịch bản (`scenario_editor_sheet.dart`) mỗi câu có nút Thu / Thu lại (tối đa 30 giây, 10 giây cuối cảnh báo, hết giờ tự dừng và giữ bản thu), chọn file, nghe lại, và ô "Chờ người dùng trả lời sau câu này" (giữ đúng cấu trúc chờ của kịch bản gốc; câu cuối không có ô). Câu còn dùng audio có sẵn hiện "Giọng mẫu của app".
- Bản thu đi qua `VoiceRecorder.stopBytes()` rồi `ScenarioRepository.importAudio`, lưu cùng chỗ file nhập. `ScenarioRepository.deleteAudio` chỉ xoá file trong thư mục audio của kho kịch bản. Thu lại hoặc xoá câu thì xoá bản vừa thu; đóng form không lưu thì xoá mọi bản thu/nhập mới; lưu kịch bản cá nhân thì xoá audio cũ không còn dùng. Bản sao kịch bản mẫu không đụng audio gốc.
- `docs/thu-giong-kich-ban-mau.md`: bản kịch để nhóm nhờ người thật thu 16 câu của 4 kịch bản mẫu, thay file trong `assets/audio/voice/`. Chưa có bản thu thật.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 211 đạt, 1 lỗi có sẵn (golden); `flutter build apk --debug` thành công. Chưa thử thu trên máy thật (quyền micro, chất lượng bản thu, chuyển sang app khác khi đang thu).

### Âm nền liền mạch khi chờ người dùng đáp (2026-11-03)

- Nhánh `codex/background-sound-continuous`. Lỗi: trong lượt chờ người dùng nói, âm nền (xe cộ, mưa…) tắt hẳn rồi có lại khi người gọi nói tiếp. Code không dừng âm nền; khả năng cao do bộ lọc giọng nói của máy (kênh cuộc gọi + micro `voiceCommunication` có khử ồn) cắt tiếng đều đều khi không có giọng.
- Đã thử và bỏ: phát âm nền kiểu `voiceCommunicationSignalling`. Trên máy người dùng âm nền không nghe thấy gì (máy giới hạn âm lượng kiểu này trong cuộc gọi, cộng âm lượng nền 0,18).
- Sửa hiện tại: âm nền và giọng cùng kiểu `voiceCommunication` (`androidCallAudioAttributes`). Micro chờ đáp (`MicReplyListener`) chuyển sang nguồn `voiceRecognition`, tắt khử ồn, giữ khử vọng. Bù lại: khi bật loa ngoài, âm nền không đều (chó sủa) có thể lọt micro và bị coi là người dùng nói, người gọi nói tiếp sớm hơn.
- Âm nền MP3 thật thay WAV tổng hợp: `assets/audio/backgrounds/{office,traffic,rain,dog}.mp3`, dùng chung cho màn gọi và kho kịch bản (`car` → `traffic.mp3`). TV và cà phê giữ WAV cũ (chưa có MP3). Đã xoá WAV bị thay; đường dẫn seed trong 3 file SQL và `DbInitializer` cập nhật theo (chỉ là dữ liệu mô tả, app không đọc).
- Người dùng thử trên máy: âm nền rất nhỏ, lúc có lúc không. Đã sửa:
  - Âm nền phát qua `BackgroundLoop` (`lib/core/services/background_loop.dart`), player just_audio với `handleInterruptions: false`. Trước đây player tự dừng khi giọng đọc hoặc app khác giành quyền phát, và dừng hẳn nếu mất quyền lâu dài.
  - Âm lượng nền là cài đặt chung `AppSettings.backgroundVolume` (mặc định 0,6, thấp nhất 0,1; trước đây cố định 0,18). Màn gọi truyền vào `AudioService.conversation(backgroundVolume:)`.
  - Một âm nền lỗi hoặc khoá lạ (ví dụ `dog` từ server, không có trong `AssetPaths`) bị bỏ qua, các âm nền khác và giọng vẫn phát.
- Nghe thử âm nền: form combo có `BackgroundPreviewControls` (nút "Nghe thử âm nền" và thanh âm lượng 10–100%, lưu vào cài đặt khi thả tay). `backgroundPreviewProvider` phát lặp như nhạc thường ra loa (không phải kiểu cuộc gọi), đổi lựa chọn thì phát lại ngay, kéo thanh trượt thì đổi âm lượng ngay. Dừng khi rời form, lưu, chọn kịch bản, xem trước cuộc gọi, bắt đầu thu/quay hoặc chuyển sang gọi video.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 227 đạt, 1 lỗi có sẵn (golden). Test: `test/core/background_sounds_test.dart`, `test/core/background_audio_test.dart`, thêm test trong `widget_test.dart` và `fake_call_screen_test.dart`. Chưa build APK (chỉ đổi Dart).
- Chưa thử trên máy thật: mức 60% có vừa ở loa trong không, âm nền còn bị cắt trong đoạn chờ không, micro `voiceRecognition` có nhận được người dùng nói khi bật loa ngoài cùng âm nền. Nghe thử phát ra loa ngoài nên to hơn khi ở trong cuộc gọi bằng loa trong. Nếu vẫn bị cắt: thử tắt "Chờ tôi nói xong mới nói tiếp" để biết lỗi do micro hay do chế độ cuộc gọi.

### Bỏ gõ lưng, chỉnh thời gian chờ sau khi người dùng nói xong (2026-11-04)

- Nhánh `feature/reply-delay-no-backtap`. Bỏ hẳn "Gõ lưng 2 lần" (Android) và hướng dẫn Back Tap (iOS) vì không kiểm tra được trên máy: `KnockDetector`, cảm biến gia tốc tuyến tính, `AppSettings.knockEnabled`, công tắc và chữ trên giao diện. Chỉ còn lật máy. Cài đặt cũ có `knockEnabled` vẫn đọc được (bỏ qua). Deep link `tron://trigger` giữ nguyên.
- Thêm `AppSettings.replyPause` (mặc định 1 giây, 0,5–5 giây, bước 0,5; lưu `replyPauseMs`): thanh trượt "Chờ sau khi bạn nói xong" dưới "Chờ tôi nói xong mới nói tiếp". Truyền vào `ReplyListener.waitForReply(endSilence:)` → `TurnDetector.reset(endSilence:)`, thay cho 0,9 giây cố định trước đây. Đang tắt tiếng hoặc micro không dùng được thì vẫn chờ cố định theo kịch bản (khoảng 3 giây).
- Sửa thêm khi test trên máy giả lập (lỗi có sẵn trên main):
  - `AudioService._playCallVoice`/`playVoice`: just_audio giữ `playing` = true sau khi phát hết, nên `play()` lần sau trả về ngay và các câu của người gọi đè lên nhau (câu 2 boss chỉ phát 0,33 s, các câu sau bị nuốt). Nay tạm dừng sau mỗi câu (`_playToEnd`).
  - `TurnDetector`: tiếng động ngắn (< `minSpeech` 0,2 s) lúc người dùng đã im không còn đếm lại khoảng im; trước đây chờ 3 giây trở lên gần như luôn bị kéo tới 20 giây trong phòng có tiếng ồn.
- Đo trên máy giả lập (micro laptop, câu trả lời phát qua loa): khoảng chờ sau khi người dùng ngừng nói là 0,98–1,37 s khi đặt 1 s; 3,10–3,33 s khi đặt 3 s (một lần 7,78 s); 5,11–5,32 s khi đặt 5 s.

### Màn Home: logo, nút viền, ảnh đại diện, kịch bản mặc định mới (2026-11-04)

- Nhánh `codex/home-ui-avatar`. Góc trên Home chỉ còn logo chữ "Trốn" (`assets/images/logo_tron.png`, cắt từ file người dùng gửi; `AssetPaths.logo`). "Nhập / Xuất" và "Tạo combo" là nút chỉ có viền (`HomeOutlineButton`).
- Ảnh đại diện người gọi: `ComboModel.avatarPath` (`media:UUID.jpg|png`) + `avatarMediaId`. Form combo có `AvatarPickerCard` (thư viện ảnh / chụp mới / xoá), `FileService.pickAvatar` dùng `image_picker`, thu nhỏ cạnh dài 512 px, tối đa 2 MB, đuôi file theo nội dung (`imageExtension`). Hiện qua `AvatarPhoto` (`lib/shared/widgets/`) ở thẻ combo, màn gọi đến/đang gọi của Điện thoại, Zalo, Messenger và avatar "Camera đang tắt" của gọi video. Ảnh lỗi/thiếu thì hiện chữ cái đầu.
- Ảnh đi theo combo: `MediaTrack.avatar` (đồng bộ server như giọng/video), sao lưu/khôi phục, `.ehc`/`TRON1.` và mã `EH-`. Ảnh luôn đi kèm gói chia sẻ kể cả khi bỏ âm thanh và video.
- Backend: `MediaKind.Image` (JPG/PNG, kiểm tra magic bytes, tối đa 2 MB), cột `Combos.AvatarMediaId` (`EnsureComboAvatarColumnAsync`, mục 1.10e trong `trondb.sql`), DTO `AvatarMediaId` cùng quy ước null = giữ, `Guid.Empty` = xoá. Gói chia sẻ trên server luôn giữ file ảnh.
- 3 combo mặc định dùng kịch bản đời thường mới (giữ ID cũ): "Sếp cần file gấp", "Mẹ gọi về ăn cơm", "Lan nhờ ra đón" (combo thứ ba đổi tên thành "Lan nhờ ra đón"). 15 file `boss_1..5`, `mother_1..5`, `friend_1..5` trong `assets/audio/voice/` là giọng máy tạm (giọng "An" của Windows, 16 kHz mono); người dùng sẽ tự thu và chép đè. Bản kịch và quy cách file: `docs/thu-giong-kich-ban-mau.md`. Dữ liệu mẫu backend (`DbInitializer`, 2 file `trondb.sql`, `backend/seed/scenarios.json`) đã khớp.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 247 đạt, 1 lỗi có sẵn (golden); `flutter build apk --debug` thành công; `dotnet build` sạch (build ra thư mục tạm vì server đang chạy khoá file exe).
- Chưa thử trên máy thật: chọn ảnh/chụp ảnh (quyền camera), ảnh hiện trên màn khoá, đồng bộ ảnh với server thật. Khi có bản thu thật: chép đè 15 file, sửa `text`/`seconds` trong `scenarios.json` nếu lời đọc khác.
- Kho kịch bản (cùng ngày): mọi kịch bản có nút ⋮ trên thẻ và ở màn chi tiết (`ScenarioMenuButton`, `runScenarioAction` trong `scenario_actions.dart`): Sửa, Tạo bản sao (kịch bản mẫu), Khôi phục bản gốc (kịch bản mẫu đã sửa), Xoá. Sửa kịch bản mẫu lưu thành kịch bản cá nhân **cùng ID** (`ScenarioEditorSheet`, `asCopy` để tạo bản sao), nên combo đang dùng tự dùng bản sửa; bản sửa đứng đúng chỗ bản gốc trong kho. Xoá kịch bản mẫu chỉ ẩn (`tron.scenarios.hiddenBuiltIns` trong SharedPreferences, chỉ lưu trên máy, không đồng bộ/sao lưu); `findScenario` vẫn tìm thấy nên combo vẫn gọi được; cuối kho có "Hiện lại N kịch bản mẫu đã xoá". Xoá kịch bản cá nhân xoá hẳn kèm file giọng chỉ nó dùng; combo đang dùng nó chuyển sang kịch bản mặc định. Ô "Thêm" âm nền là `AddBackgroundTile` (icon trên, chữ dưới) nên không xuống dòng trên màn hẹp. Test: `test/features/scenarios/scenario_library_actions_test.dart`, thêm test trong `scenario_repository_test.dart` và `scenario_editor_sheet_test.dart`. `flutter test` 253 đạt, 1 lỗi có sẵn (golden).

### Gác máy xong về màn hình chính (2026-11-04)

- Nhánh `codex/leave-app-after-call`. Mọi cách kết thúc cuộc gọi thật đi qua `_hangUp()` (`fake_call_screen.dart`): nút kết thúc, từ chối/tin nhắn, video hết (chế độ tắt máy), cuộc gọi nhỡ quá 60 giây. Giữ nút gác máy để gửi SOS thì vẫn ở lại app.
- Đã trả lời rồi gác máy: giữ màn đang gọi 1,5 giây (`FakeCallScreen.endedHold`), đồng hồ đổi thành "Cuộc gọi kết thúc" (Messenger: "Cuộc gọi đã kết thúc"), các nút mờ và không bấm được (`CallEndFade`); gọi video thì video dừng ở khung cuối, camera tắt. Từ chối thì đóng ngay, không có màn này. Bản xem thử cũng hiện màn kết thúc rồi quay về form.
- Cuộc gọi thật trên Android: `CallDeviceService.leaveApp()` → kênh `tron/call` `leaveApp` → `moveTaskToBack(true)` (về màn hình chính, hoặc màn khóa nếu gọi lúc khóa máy). App không bị tắt hẳn để hẹn giờ, "Sẵn sàng khi tắt màn hình", báo an toàn SOS vẫn chạy; vẫn có trong danh sách app gần đây. Chờ app ra nền (tối đa 1 giây) rồi bỏ màn gọi bằng `removeRoute` (không hiệu ứng) để mở lại thấy trang chủ. iOS/web không hỗ trợ thì đóng màn gọi như cũ.
- Cài đặt `AppSettings.leaveAppAfterCall` (mặc định bật, khoá `leaveAppAfterCall`), công tắc "Về màn hình chính sau khi tắt máy" chỉ hiện trên Android.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 243 đạt, 1 lỗi có sẵn (golden); `flutter build apk --debug` thành công. Chưa thử trên máy thật: hiệu ứng app trượt ra, gác máy lúc đang khóa máy, chữ kết thúc có khớp từng hãng máy/app thật không.

### Không hiện thông báo "Cuộc gọi đến" khi đang mở app (2026-11-05)

- Nhánh `codex/no-pre-call-notification`. Trước đây báo thức hệ thống (`CallAlarmService.scheduleCall`) đặt đúng giờ hẹn, còn đồng hồ trong app kiểm tra mỗi 0,2 giây, nên khi đang mở app thông báo "Cuộc gọi đến · Chạm để nghe" thường hiện ra trước khi app kịp huỷ.
- Nay báo thức đặt trễ `CallNotifier.alarmDelay` (1,5 giây): app đang mở thì tự đổ chuông đúng giờ và huỷ báo thức trước khi nó chạy. Khoá máy hoặc app ở nền thì vẫn dùng thông báo (full-screen intent) như cũ, chỉ trễ 1,5 giây. Người dùng chọn giữ thông báo cho trường hợp khoá máy/nền.
- Kiểm tra: `flutter analyze` sạch; `flutter test` 261 đạt, 1 lỗi có sẵn (golden). Chưa thử trên máy thật.

### Landing page và tải APK (2026-11-06)

- Nhánh `codex/landing-page`. Trang tĩnh ở `landing/` (`index.html`, `styles.css`, ảnh mascot/màn hình lấy từ slide thuyết trình, font Be Vietnam Pro và màu của `AppColors`). APK là `landing/downloads/tron.apk` (bản release build ngày 2026-11-06 từ `main`, ký bằng khoá debug, ~89 MB, SHA-256 ghi trên trang). Mã QR `assets/img/qr.svg` trỏ tới `https://twoofwn.github.io/tron/#tai-app`.
- `.github/workflows/pages.yml` đăng `landing/` lên GitHub Pages khi push vào `main` có đổi trong `landing/`, hoặc chạy tay. Lần đầu phải bật Settings → Pages → Source = "GitHub Actions".
- Cập nhật APK: build release, chép đè `landing/downloads/tron.apk`, sửa dung lượng và SHA-256 trong `index.html`. Mỗi lần đổi APK làm repo nặng thêm ~90 MB; GitHub chặn file > 100 MB.
- Trang không nhắc "Gõ lưng" vì đã bỏ; ảnh màn Home trong slide vẫn còn chữ "gõ lưng".
