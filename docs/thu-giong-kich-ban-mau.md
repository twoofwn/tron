# Kịch bản thu giọng cho 3 combo mặc định

Ba combo có sẵn khi cài app ("Sếp gọi gấp", "Mẹ gọi về nhà", "Lan nhờ ra đón") dùng ba kịch bản dưới đây. File trong `assets/audio/voice/` hiện là **giọng máy đọc tạm** (giọng "An" của Windows, một giọng nam cho cả ba vai). Thu xong thì chép đè đúng tên file là xong, không phải sửa code.

App phát từng câu một. Ở dòng *(người dùng trả lời)*, người gọi im lặng chờ người dùng nói xong rồi mới phát câu tiếp. Vì vậy **mỗi câu là một file riêng**, không gộp nhiều câu vào một file.

## Quy cách file

| Mục | Yêu cầu |
| --- | --- |
| Định dạng | WAV (PCM), **mono**, **16 bit** |
| Tần số mẫu | 16000, 22050 hoặc 44100 Hz (khuyên dùng 22050 Hz) |
| Mỗi file | Đúng **một câu** trong bảng, đọc trọn câu |
| Tên file | `<vai>_<số thứ tự>.wav`, chữ thường, không dấu, không khoảng trắng. Ví dụ `boss_1.wav`, `mother_3.wav`, `friend_5.wav`. Số thứ tự bắt đầu từ 1, không thêm số 0 |
| Đầu và cuối file | Cắt khoảng lặng, chỉ chừa 0,1–0,2 giây. Lặng dài ở cuối làm người gọi chậm chuyển sang chờ người dùng |
| Độ lớn | To rõ, không rè (đỉnh khoảng -3 dB). Các câu cùng vai to đều nhau |
| Dung lượng | Dưới 1 MB mỗi file (một câu 5 giây ở 22050 Hz mono khoảng 220 KB) |
| Nơi chép | `assets/audio/voice/`, **chép đè** file cùng tên |

Ba vai dùng ba tiền tố: `boss_` (sếp), `mother_` (mẹ), `friend_` (Lan).

## Trước khi thu

- **Người đọc phải đồng ý** cho giọng mình được đóng gói trong app. Nên có tin nhắn xác nhận. Không dùng bản ghi cuộc gọi hay giọng người chưa đồng ý.
- **Chỗ thu:** phòng yên tĩnh, ít vang (có rèm, chăn gối thì tốt hơn phòng trống). Tắt quạt, điều hòa nếu được. Không cần thu âm nền: app tự phát âm nền (văn phòng, TV, xe cộ, quán cà phê).
- **Thiết bị:** điện thoại là đủ. Cầm máy cách miệng 15–20 cm, hơi lệch sang bên để không phì hơi.
- **Cách đọc:** nói như đang gọi điện thật, không đọc như đọc bài. Có thể nói hơi nhanh, có "à", "ừ", có hơi thở. Mỗi câu thu 2–3 lần, giữ lần tự nhiên nhất.
- Được đổi chữ cho hợp giọng vùng miền ("nhé" → "nghen", "đấy" → "đó", "tớ/cậu" → "tui/bà"…). Đổi thì báo lại để sửa chữ hiển thị trong app cho khớp.

## Kịch bản 1: "Sếp cần file gấp" (combo "Sếp gọi gấp")

**Vai:** Sếp Hùng, nam 30–45 tuổi. **Giọng:** bình thường, hơi vội vì đang ngồi với khách, không quát. **Giao diện:** Zalo. **Âm nền:** văn phòng.

**Tình huống:** sếp đang tiếp khách, cần bạn gửi lại file báo giá, nên bạn có lý do rời đi ngay.

| File | Câu thoại | Cách đọc |
| --- | --- | --- |
| `boss_1.wav` | Alo, em đang ở đâu đấy? | Nhanh, giọng công việc |
| | *(người dùng trả lời)* | |
| `boss_2.wav` | Anh đang ngồi với khách, họ muốn xem lại cái file báo giá em làm hôm qua. | Hơi hạ giọng như đang có khách bên cạnh |
| | *(người dùng trả lời)* | |
| `boss_3.wav` | Trên máy anh mở không được. Em về máy gửi lại cho anh bản mới nhất nhé? | Hơi sốt ruột, lên giọng ở cuối |
| | *(người dùng trả lời)* | |
| `boss_4.wav` | Ừ, khoảng mười lăm phút nữa là được đúng không? Anh đợi. | Dịu lại, đồng ý |
| `boss_5.wav` | Gửi xong nhắn anh một tiếng nhé. Thế nhé. | Chốt nhanh, như sắp cúp máy |

## Kịch bản 2: "Mẹ gọi về ăn cơm" (combo "Mẹ gọi về nhà")

**Vai:** Mẹ, nữ 45–60 tuổi. **Giọng:** vui, thân mật, hơi giục. **Giao diện:** Điện thoại, chuông cổ điển. **Âm nền:** tiếng TV trong nhà.

**Tình huống:** ông bà nội lên chơi bất ngờ, mẹ gọi con về ăn cơm cả nhà.

| File | Câu thoại | Cách đọc |
| --- | --- | --- |
| `mother_1.wav` | Alo, con à? Con đang ở đâu đấy? | Lên giọng ở "à", tự nhiên |
| | *(người dùng trả lời)* | |
| `mother_2.wav` | Ông bà nội vừa lên chơi, đang ngồi ở nhà mình đây này. | Vui, hơi bất ngờ |
| | *(người dùng trả lời)* | |
| `mother_3.wav` | Ông bà cứ hỏi con mãi. Con về ăn cơm với cả nhà luôn nhé. | Giục nhẹ, thương con |
| | *(người dùng trả lời)* | |
| `mother_4.wav` | Ừ, mẹ nấu cơm rồi đấy, về sớm nhé. | Hài lòng |
| `mother_5.wav` | À, tiện đường mua giúp mẹ chai nước mắm ở đầu ngõ nhé con. | Như chợt nhớ ra, nói nhanh hơn |

## Kịch bản 3: "Lan nhờ ra đón" (combo "Lan nhờ ra đón")

**Vai:** Lan, bạn thân, nữ 18–25 tuổi. **Giọng:** thân, hơi than thở, không hoảng. **Giao diện:** Messenger. **Âm nền:** xe cộ và quán cà phê.

**Tình huống:** xe Lan thủng săm, điện thoại sắp hết pin, nhờ bạn ra quán cà phê gần nhà.

| File | Câu thoại | Cách đọc |
| --- | --- | --- |
| `friend_1.wav` | Ê, cậu đang ở đâu thế? | Thân, nhanh |
| | *(người dùng trả lời)* | |
| `friend_2.wav` | Xe tớ bị thủng săm rồi, đang ngồi ở quán cà phê gần nhà cậu nè. | Than thở |
| | *(người dùng trả lời)* | |
| `friend_3.wav` | Điện thoại tớ cũng sắp hết pin. Cậu ra đây với tớ một lát được không? | Nài nỉ, lên giọng ở cuối |
| | *(người dùng trả lời)* | |
| `friend_4.wav` | Ừ, cậu ra nhanh nhé, tớ ngồi bàn ngay ngoài cửa. | Nhẹ nhõm |
| `friend_5.wav` | Đến nơi thì gọi tớ nha. | Chốt, vui |

Tổng cộng **15 file**: `boss_1` → `boss_5`, `mother_1` → `mother_5`, `friend_1` → `friend_5`.

## Đổi bản thu sang đúng định dạng

**Cách 1: Audacity (miễn phí, không cần dòng lệnh)**

1. Mở file ghi âm (m4a, mp3…). Chọn và xoá khoảng lặng ở đầu, cuối.
2. Nếu bản thu là stereo: menu **Tracks → Mix → Mix Stereo Down to Mono**.
3. Góc dưới trái, chỉnh **Project Rate** thành 22050.
4. **File → Export Audio**, chọn *WAV (Microsoft)*, *Signed 16-bit PCM*, đặt đúng tên file, ví dụ `boss_2.wav`.

**Cách 2: ffmpeg** (cần cài [ffmpeg](https://ffmpeg.org)):

```bash
ffmpeg -i ban_thu.m4a -ac 1 -ar 22050 -sample_fmt s16 boss_2.wav
```

## Sau khi chép file vào

1. Báo lại nếu có câu đã đổi chữ khi đọc, để sửa `text` trong `assets/scenarios/scenarios.json` (màn chi tiết kịch bản hiện chữ của từng câu).
2. Chạy `flutter test`: có test kiểm tra đủ file audio mẫu.
3. Mở app, chọn từng combo, bấm **Xem thử cuộc gọi**, trả lời thử xem người gọi có chờ đúng lượt không.
4. Commit riêng các file giọng, ghi rõ trong mô tả là người đọc đã đồng ý.

## Kịch bản "Chủ trọ đòi tiền nhà"

Kịch bản này vẫn có trong kho kịch bản nhưng không thuộc 3 combo mặc định, nên giữ nguyên lời và giọng máy cũ (`landlord_1.wav` → `landlord_4.wav`). Muốn thu thì làm theo cùng quy cách trên.
