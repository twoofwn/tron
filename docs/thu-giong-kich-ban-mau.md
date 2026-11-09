# Giọng thu cho 6 combo mặc định

Sáu combo có sẵn khi cài app dùng sáu kịch bản dưới đây, tất cả đều gọi bằng giao diện Zalo. File giọng nằm trong `assets/audio/voice/`. Muốn thay giọng thì chép đè đúng tên file, không phải sửa code.

App phát từng câu một. Ở dòng *(người dùng trả lời)*, người gọi im lặng chờ người dùng nói xong rồi mới phát câu tiếp. Vì vậy **mỗi câu là một file riêng**, không gộp nhiều câu vào một file.

## Quy cách file

| Mục | Yêu cầu |
| --- | --- |
| Định dạng | M4A (AAC), như file ghi âm của điện thoại. Dùng MP3 hoặc WAV cũng được, nhưng phải đổi đuôi trong `audioPath` của `assets/scenarios/scenarios.json` |
| Mỗi file | Đúng **một câu** trong bảng, đọc trọn câu |
| Tên file | `KB<số kịch bản>_C<số câu>.m4a`, viết đúng hoa/thường (Android phân biệt). Ví dụ `KB1_C1.m4a`, `KB3_C2.m4a` |
| Đầu và cuối file | Cắt khoảng lặng, chỉ chừa 0,1–0,2 giây. Lặng dài ở cuối làm người gọi chậm chuyển sang chờ người dùng |
| Độ lớn | To rõ, không rè. Các câu cùng vai to đều nhau |
| Dung lượng | Dưới 1 MB mỗi file |
| Nơi chép | `assets/audio/voice/`, **chép đè** file cùng tên |

## Kịch bản 1: "Người yêu gọi"

**Tên hiển thị:** Bà chã húi <3. **Nhóm:** Cá nhân. **Âm nền:** không có.

| File | Câu thoại |
| --- | --- |
| `KB1_C1.m4a` | Alo, anh đang đâu đấy? |
| | *(người dùng trả lời)* |
| `KB1_C2.m4a` | Anh về lai em ra viện với, em đau bụng quá. |

## Kịch bản 2: "Bố gọi"

**Tên hiển thị:** Bố. **Nhóm:** Gia đình. **Âm nền:** tiếng TV.

| File | Câu thoại |
| --- | --- |
| `KB2_C1.m4a` | Alo, mày đang đâu đấy? |
| | *(người dùng trả lời)* |
| `KB2_C2.m4a` | Nhà đang bao việc mà không lo, tao cho mày 5 phút về ngay cho tao. |

## Kịch bản 3: "Anh trai gọi (Tình huống đường vắng)"

**Tên hiển thị:** Khọm già. **Nhóm:** Gia đình. **Âm nền:** xe cộ.

| File | Câu thoại |
| --- | --- |
| `KB3_C1.m4a` | Alo, đi đến đâu rồi? |
| | *(người dùng trả lời)* |
| `KB3_C2.m4a` | Đợi tí, tao sắp đến nơi rồi. |

## Kịch bản 4: "Chủ nợ gọi"

**Tên hiển thị:** Thắng Cá Chép. **Nhóm:** Cá nhân. **Âm nền:** không có.

| File | Câu thoại |
| --- | --- |
| `KB4_C1.m4a` | Alo, sợ cái gì mà không bắt máy? Mày tưởng mày cầm 50 triệu của tao mà mày chạy được à? |
| | *(người dùng trả lời)* |
| `KB4_C2.m4a` | Giờ tao biết mày ở đâu rồi đấy, mày thấy mày chạy được thì chạy nhanh vào. |
| | *(người dùng trả lời)* |
| `KB4_C3.m4a` | Mày cứ chạy đi, đừng để tao bắt được. |

## Kịch bản 5: "Có người lạ vào trọ"

**Tên hiển thị:** Roommate. **Nhóm:** Cá nhân. **Âm nền:** không có.

| File | Câu thoại |
| --- | --- |
| `KB5_C1.m4a` | Ê, trọ mình có cái ông già già nào vào ý. |
| | *(người dùng trả lời)* |
| `KB5_C2.m4a` | Mày ơi, tao sợ vãi, mày về đi. |

## Kịch bản 6: "Bạn đến đón"

**Tên hiển thị:** Cốt. **Nhóm:** Cá nhân. **Âm nền:** không có.

| File | Câu thoại |
| --- | --- |
| `KB6_C1.m4a` | Alo, tới chưa má, lâu vậy? |
| | *(người dùng trả lời)* |
| `KB6_C2.m4a` | Ok, được rồi, giờ mày chụp cái biển số xe gửi qua đây đi, rồi tao xuống dưới nhà tao canh, tao đón mày nè. |

## Sau khi chép file vào

1. Nếu lời đọc khác chữ trong bảng, sửa `text` của câu đó trong `assets/scenarios/scenarios.json` (màn chi tiết kịch bản hiện chữ của từng câu). Độ dài câu khác nhiều thì sửa cả `seconds`.
2. Chạy `flutter test`: có test kiểm tra đủ file audio mẫu.
3. Dừng app rồi chạy lại (`flutter run`) hoặc build lại APK. Hot reload không nạp file âm thanh mới.
4. Mở app, chọn từng combo, bấm **Xem thử cuộc gọi**, trả lời thử xem người gọi có chờ đúng lượt không.
5. Commit riêng các file giọng, ghi rõ trong mô tả là người đọc đã đồng ý.

## File giọng cũ còn giữ

`boss_1.wav`, `boss_2.wav`, `mother_1.wav`, `mother_2.wav`, `friend_1.wav`, `friend_2.wav` không còn thuộc kịch bản mặc định nào. Chúng được giữ lại vì các kịch bản trong gói mẫu của chợ chia sẻ (dữ liệu mẫu backend) vẫn dùng. Chỉ xoá khi đã sửa các gói đó.
