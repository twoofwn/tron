# TRỐN

Ứng dụng Flutter tạo cuộc gọi giả theo combo, thiết kế tối mặc định, điểm nhấn vàng và các thẻ kính mờ. Có ba màn hình chính: Trang chủ, Tạo / sửa combo, Chia sẻ combo.

## Chạy ứng dụng

```sh
flutter pub get
flutter run
```

Flutter SDK cần đi kèm Dart 3.13.2 trở lên theo `pubspec.yaml`. Có thể chạy bản xem trước trên Chrome bằng `flutter run -d chrome`. Android / iOS dùng trình chọn file, camera và bảng chia sẻ của hệ điều hành.

## Các luồng đã triển khai

- Trang chủ: chọn một combo, tạo / sửa / nhân bản / xóa, chọn 10 giây / 30 giây / 1 phút / 5 phút, hẹn / đổi / hủy lịch gọi, chuyển sáng / tối.
- Tạo combo: tên, thư viện hội thoại, nghe thử bằng TTS tiếng Việt, giao diện Điện thoại / Zalo / Messenger, chuông mặc định / cổ điển / MP3 cá nhân, chọn nhiều âm nền, nhập âm nền cá nhân, xem trước, kiểm tra tên và lưu.
- Xuất: chọn nhiều / tất cả, tùy chọn kèm âm thanh cá nhân, tạo mã và QR, lưu `.ehc`, mở bảng chia sẻ hệ thống.
- Nhập: mở `.ehc`, quét QR hoặc dán mã đầy đủ, xem trước, chọn combo, bỏ qua hoặc tạo bản sao khi ID trùng, xác nhận lưu.
- Màn hình phụ: cuộc gọi đến / trả lời / kết thúc, đồng hồ cuộc gọi, tắt / bật âm thanh; máy tính ngụy trang; lưu số người tin cậy và mở trình gọi điện.
- Gọi video: ở form combo chọn "Gọi thoại" hoặc "Gọi video". Gọi video có thẻ "Video người gọi" để quay ngay trong app (camera trước, tối đa 60 giây, có tiếng) hoặc chọn file MP4 có sẵn (tối đa 20 MB), xem lại, quay lại, xoá. Khi bắt máy, video phủ kín màn hình, khung nhỏ góc trên hiện camera trước của người dùng (chỉ xem, không quay, không thu tiếng), có nút đổi camera, tắt camera, tắt tiếng, kết thúc. Combo gọi video chưa có video, hoặc video không phát được, thì hiện như người gọi tắt camera và phát giọng tự thu / giọng máy đọc như gọi thoại.
- Kho kịch bản (màn 5–6): mở từ form combo bằng thẻ kịch bản. Tìm kiếm không dấu kèm bộ lọc, xem chi tiết, nghe thử từng câu (chờ chạm "Tiếp tục câu thoại"), chọn âm nền, tạo / sửa kịch bản cá nhân, sao chép kịch bản có sẵn, nhập file MP3 / M4A / WAV. Chỉ khi bấm "Dùng kịch bản này" thì kịch bản mới đổi trong combo; quay lại không đổi gì.

## Kiến trúc và lưu trữ

`lib/app` chứa router và theme. `core` chứa service và widget chung. `features` tách Home, Combo, Fake call, Scenario, Sharing. `shared` chứa enum và thành phần dùng chung.

Riverpod `AsyncNotifier` quản lý danh sách combo và dữ liệu bất đồng bộ. `Notifier` quản lý lựa chọn, hẹn giờ, trạng thái cuộc gọi và phát kịch bản. Tab và dữ liệu đang nhập trong form là local UI state. Repository chịu trách nhiệm đọc / ghi.

Combo và tùy chọn giao diện lưu bằng SharedPreferences. Âm thanh cá nhân được sao chép vào thư mục riêng của ứng dụng trên Android / iOS; model chỉ lưu định danh `media:UUID.mp3`. Bản web lưu âm thanh riêng dưới khóa media trong bộ nhớ trình duyệt, có giới hạn dung lượng của trình duyệt.

## Định dạng chia sẻ ngoại tuyến

`.ehc` là JSON UTF-8 có `format: tron.ehc`, `version: 1`, ID gói, danh sách combo và các âm thanh được mã hóa base64 khi người dùng chọn đính kèm. Bytes chỉ nằm trong gói chia sẻ, không nằm trong dữ liệu combo lưu trên máy. Khi nhập, âm thanh được tạo thành file mới và các đường dẫn được thay thế.

Mã đầy đủ có dạng `TRON1.<base64url của gói>`, chứa dữ liệu trực tiếp nên nhập được trên thiết bị khác mà không có server. Nhãn `EH-…` chỉ là ID hiển thị, không phải mã để nhập. QR chứa mã đầy đủ. Gói quá lớn cho QR chuyển sang chia sẻ file `.ehc`. Mỗi file âm thanh tối đa 10 MB, video người gọi tối đa 20 MB; mỗi gói tối đa 25 MB và 100 combo. Khi bỏ tùy chọn đính kèm, chuông cá nhân trở về chuông theo giao diện và âm nền cá nhân được bỏ khỏi gói.

## Giới hạn nền tảng

- Hẹn giờ hoạt động khi ứng dụng còn mở, kể cả trong màn hình ngụy trang. Chưa có dịch vụ nền / thông báo cuộc gọi hệ thống để bảo đảm kích hoạt khi ứng dụng bị đóng hoặc thiết bị khóa.
- Hội thoại dùng giọng TTS `vi-VN` có sẵn trên thiết bị; cần cài giọng tiếng Việt để nghe. TTS có thể cần kết nối mạng tùy giọng và hệ điều hành.
- Chuông và âm nền đi kèm là các âm thanh demo tự tạo bằng `tool/generate_audio.py`. Không dùng âm thanh thương hiệu gốc; giao diện mô phỏng không thực hiện cuộc gọi qua Zalo / Messenger.
- Quay video người gọi chỉ có trên Android / iOS (gói `camera`); bản web chỉ chọn được file MP4 có sẵn. Video lưu trong thư mục media của app dưới dạng `media:UUID.mp4`.
- Camera, âm thanh, chọn file và chia sẻ phụ thuộc khả năng và quyền của thiết bị. Cần kiểm tra trên thiết bị thật trước khi phát hành Android / iOS. Bản web yêu cầu HTTPS hoặc localhost để dùng camera, và trình duyệt có thể yêu cầu tương tác trước khi phát âm thanh.
- Build web JavaScript được hỗ trợ. Plugin `flutter_tts` hiện có cảnh báo tương thích WebAssembly; chưa xác nhận bản build `--wasm`.
- Máy tính là màn hình ngụy trang mặc định. SOS mở trình gọi điện với số người dùng lưu; ứng dụng không tự gọi hoặc gửi tin nhắn.

## Kiểm tra

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

Test bao gồm lưu dữ liệu, thao tác combo, chính sách trùng, mã chia sẻ ngoại tuyến, khôi phục âm thanh, từ chối gói không hợp lệ, hẹn / hủy cuộc gọi, điều hướng và bố cục điện thoại nhỏ. Ảnh kiểm tra trực quan nằm trong `test/goldens`; cập nhật có chủ ý bằng `flutter test --update-goldens`.

Roboto được phân phối kèm giấy phép trong `assets/fonts/roboto_license.txt` để giao diện không phụ thuộc tải font từ mạng.

## Kho kịch bản

Mã nguồn nằm ở `lib/features/scenarios/` (models, data, providers, presentation, services). Dữ liệu có sẵn ở `assets/scenarios/scenarios.json`, giọng thoại ở `assets/audio/voice/`, âm nền ở `assets/audio/ambient/`. Kịch bản cá nhân và file âm thanh nhập từ máy lưu trong thư mục tài liệu của ứng dụng (`escapehatch/`), không lưu trên web.

- ID cũ của combo (`boss`, `mother`, `friend`) được ánh xạ sang `boss-server`, `mother-urgent`, `friend-lan-demo` trong `ScenarioLookup`. Kịch bản `delivery` cũ vẫn dùng được trong combo đã lưu nhưng không còn trong kho mới.
- Cuộc gọi giả vẫn đọc hội thoại bằng TTS: nội dung các câu thoại của kịch bản được nối lại thành một đoạn. Nghe thử trong kho dùng file audio demo và `audioplayers`, nên hai đường phát này khác nhau.
- Kịch bản cá nhân gắn với file trên máy, nên combo dùng chúng không nhập được trên thiết bị khác; gói chia sẻ chỉ chấp nhận kịch bản có sẵn.
- Âm nền chọn trong kho chưa được lưu vào combo; combo vẫn dùng bộ chọn âm nền riêng ở form.
- `tool/generate_demo_audio.py` tạo lại giọng thoại demo (cần macOS với giọng `Linh`).


## Backend .NET 9 & SQL Server (`backend/`)

Dự án bao gồm hệ thống backend ASP.NET Core 9 Web API kết nối SQL Server 2022 trong thư mục `backend/`:

- **Kiến trúc**: Tổ chức theo mô hình 5 thư mục trong `backend/src/Tron.Api/`: `Controllers`, `Models`, `Services`, `Repositories`, `Db` (khởi tạo DB từ `trondb.sql`).
- **Tính năng**: Đăng ký / đăng nhập (`JWT + Refresh Token xoay vòng`), quản lý danh mục kịch bản & âm nền (`Catalog`), lưu trữ file âm thanh trên ổ đĩa server (`DiskMediaStorage`), sao lưu & khôi phục dữ liệu (`PUT/GET /api/v1/backup`) và chia sẻ trực tuyến bằng mã `EH-XXXXXX` (`POST/GET /api/v1/shares`).
- **Chạy backend**:
  ```sh
  cd backend
  dotnet run --project src/Tron.Api
  ```
- **Chạy trên điện thoại Android thật (cắm USB)**: bản debug trên Android mặc định gọi `10.0.2.2:5080`, địa chỉ này chỉ máy ảo dùng được. Script sau tự bật backend (cửa sổ "Tron backend") nếu chưa chạy, nối cổng 5080 của điện thoại về máy tính bằng `adb reverse`, rồi chạy `flutter run` với `API_BASE_URL=http://localhost:5080`:
  ```sh
  powershell -ExecutionPolicy Bypass -File tool/dev_phone.ps1
  ```
  Tham số thêm được chuyển cho `flutter run` (ví dụ `-d <mã thiết bị>`). Rút cáp rồi cắm lại thì chạy lại script. Trong VS Code, chọn cấu hình "Flutter (Điện thoại thật + backend)" để làm tương tự (dùng task trong `.vscode/tasks.json`).
- **Chạy Flutter kèm cổng đăng nhập bắt buộc**:
  ```sh
  flutter run --dart-define=REQUIRE_AUTH=true --dart-define=API_BASE_URL=http://localhost:5080
  ```
