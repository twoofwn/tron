# TRỐN Backend (.NET 9 + SQL Server)

Backend REST API cho ứng dụng **TRỐN (EscapeHatch)** được tổ chức theo mô hình 5 lớp chuẩn trong `src/Tron.Api/`:
- `Controllers/`: Các REST API Controller (`AuthController`, `MeController`, `CatalogController`, `MediaController`, `BackupController`, `SharesController`, `HealthController`).
- `Models/`: Các Entity ánh xạ bảng SQL, Enum, DomainException và các Request/Response DTO.
- `Services/`: Xử lý nghiệp vụ (`AuthService`, `CatalogAndMediaService`, `BackupAndShareService`, `JwtTokenService`, `DiskMediaStorage`, `StorageCleanupWorker`).
- `Repositories/`: Truy vấn dữ liệu qua EF Core (`UserRepository`, `CatalogRepository`, `MediaRepository`, `BackupRepository`, `ShareRepository`).
- `Db/`: `TronDbContext` và `SqlScriptInitializer` (thực thi script `trondb.sql`).

## Tính năng chính

- **Khởi tạo Database từ `trondb.sql`**: Tạo đầy đủ 15 bảng, ràng buộc, index và nạp sẵn 4 kịch bản mẫu (22 bước hội thoại), 7 âm nền hợp nhất, 4 nhạc chuông và 4 ánh xạ ID cũ.
- **Xác thực bắt buộc (`JWT + Refresh Token xoay vòng`)**: Đăng ký, đăng nhập, làm mới phiên, đăng xuất, đổi mật khẩu, khóa tạm khi sai mật khẩu nhiều lần, xóa tài khoản kèm toàn bộ dữ liệu và file trên ổ đĩa.
- **Lưu trữ âm thanh và video trên ổ đĩa (`DiskMediaStorage`)**: Kiểm tra định dạng bằng magic bytes (`MP3`, `M4A`, `WAV`, video `MP4`), giới hạn 10 MB/file âm thanh và 20 MB/video (`DomainLimits:MaxVideoFileBytes`), hạn mức 200 MB/tài khoản, chống tải trùng bằng `SHA-256`, tự dọn file mồ côi.
- **Cuộc gọi video**: `Combos.CallType` (`Voice`/`Video`) và `Combos.VideoMediaId` (FK tới `MediaFiles`, tự thêm vào database cũ khi khởi động). Trong API combo/sao lưu/chia sẻ, `callType` và `videoMediaId` theo cùng quy ước với `voiceMediaId`: không gửi = giữ nguyên, `Guid.Empty` = xoá video. Video tải lên với `kind=Video`.
- **Sao lưu & Khôi phục (`Backup & Restore`)**: Lưu ảnh chụp toàn bộ combo, kịch bản cá nhân, âm nền cá nhân, cài đặt và âm thanh đính kèm của tài khoản trong 1 transaction.
- **Chia sẻ trực tuyến (`EH-XXXXXX`)**: Tạo mã chia sẻ ngắn 6 ký tự Base32 kèm thời hạn, hỗ trợ cả kịch bản cá nhân và âm thanh riêng, cho phép thu hồi bất kỳ lúc nào.

## Chạy trên máy cá nhân (Development)

### Yêu cầu
- .NET 9 SDK (`9.0.x`)
- SQL Server 2022 (Developer / Express trên `localhost`, hoặc Docker Compose)

### Các bước chạy

1. Tạo database từ file `trondb.sql` (bằng SSMS hoặc `sqlcmd`):
   ```powershell
   sqlcmd -S localhost -E -f 65001 -i trondb.sql
   ```
   *(Hoặc chạy thẳng API bên dưới — ứng dụng sẽ tự động đọc và thực thi `trondb.sql` khi khởi động nếu database chưa tồn tại)*.
2. Chạy REST API:
   ```powershell
   cd backend
   dotnet build
   dotnet run --project src/Tron.Api
   ```

- API lắng nghe tại `http://localhost:5080`.
- Tài liệu OpenAPI / Scalar UI: `http://localhost:5080/scalar/v1`.
- Kiểm tra trạng thái: `GET http://localhost:5080/api/v1/health/ready`.

## Triển khai lên Server (Production)

### Phương án A: Linux VPS với Docker Compose + Nginx
1. Sao chép `.env.example` thành `.env` và điền `MSSQL_SA_PASSWORD`, `JWT_SIGNING_KEY` (tối thiểu 32 ký tự ngẫu nhiên).
2. Chạy:
   ```bash
   docker compose up -d --build
   ```
3. Cấu hình Nginx reverse proxy kèm chứng chỉ Let's Encrypt theo mẫu `deploy/nginx.conf`.

### Phương án B: Windows Server (IIS + SQL Server)
1. Cài đặt **.NET 9 Hosting Bundle** và **SQL Server 2022**.
2. Chạy `trondb.sql` trên SQL Server để tạo database `TronDb`.
3. Tạo thư mục lưu trữ âm thanh ngoài thư mục web (ví dụ `D:\TronData\media`) và cấp quyền Modify cho Application Pool.
4. Publish ứng dụng:
   ```powershell
   dotnet publish src/Tron.Api -c Release -o C:\inetpub\tron-api
   ```
5. Thiết lập biến môi trường cho site IIS:
   - `ConnectionStrings__Tron`
   - `Jwt__SigningKey`
   - `Storage__MediaRoot=D:\TronData\media`
