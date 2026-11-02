# Bản kịch thu giọng cho kịch bản mẫu

Bốn kịch bản mẫu trong app hiện dùng giọng máy tạo lúc làm demo, nghe giả. Tài liệu này để nhờ người thật đọc từng câu, rồi thay vào `assets/audio/voice/`. Mỗi câu một file riêng, để app phát câu này, chờ người dùng trả lời xong rồi mới phát câu sau.

## Trước khi thu

- **Sự đồng ý:** người đọc phải đồng ý cho giọng mình được đóng gói trong app và phát cho mọi người dùng. Nên có tin nhắn hoặc giấy xác nhận. Không dùng bản ghi âm cuộc gọi hay giọng của người chưa đồng ý.
- **Chỗ thu:** phòng yên tĩnh, ít vang (phòng có rèm, chăn gối tốt hơn phòng trống). Tắt quạt, điều hòa nếu được.
- **Thiết bị:** điện thoại là đủ. Để máy cách miệng khoảng 15–20 cm, hơi lệch sang bên để không bị phì hơi. Dùng app ghi âm có sẵn của máy hoặc Audacity trên máy tính.
- **Cách đọc:** nói như đang **gọi điện thật** cho người thân/nhân viên, không đọc như đọc bài. Được nói hơi nhanh, có hơi thở, có "à", "ừ" tự nhiên. Đọc mỗi câu 2–3 lần, giữ lần tự nhiên nhất.
- **Đầu và cuối file:** cắt bớt khoảng lặng, chỉ chừa khoảng 0,1–0,2 giây. Khoảng lặng dài ở cuối làm người gọi chậm chuyển sang chờ người dùng trả lời.
- **Độ lớn:** to rõ nhưng không bị rè (đỉnh khoảng -3 dB). Các câu trong cùng kịch bản nên to đều nhau.

## Yêu cầu file

- Định dạng **WAV, mono, 16 bit, 22050 Hz hoặc 44100 Hz**. File hiện có là 22050 Hz.
- **Giữ đúng tên file** trong bảng dưới, chép đè vào `assets/audio/voice/`. Như vậy không phải sửa code.
- Muốn dùng MP3 cho nhẹ thì đổi đuôi `audioPath` tương ứng trong `assets/scenarios/scenarios.json`.
- Đổi file ghi âm sang đúng định dạng (cần cài [ffmpeg](https://ffmpeg.org)):

  ```bash
  ffmpeg -i ban_thu.m4a -ac 1 -ar 22050 -sample_fmt s16 mother_1.wav
  ```

## Kịch bản 1 — "Mẹ gọi về gấp"

**Vai:** Mẹ, nữ khoảng 45–60 tuổi. **Giọng:** lo lắng, gấp nhưng thương con. Âm nền khi gọi: tiếng TV.

| File | Câu thoại | Gợi ý cách đọc |
| --- | --- | --- |
| `mother_1.wav` | Alo, con à? | Hơi gấp, lên giọng ở "à" |
| *(người dùng trả lời)* | | |
| `mother_2.wav` | Ở nhà có việc gấp, con về ngay nhé. | Hạ giọng, nghiêm hơn |
| *(người dùng trả lời)* | | |
| `mother_3.wav` | Không được, bố con đang mệt. Về liền đi. | Gạt đi, sốt ruột |
| `mother_4.wav` | Nhanh lên nhé con. | Dịu lại, dặn dò |

## Kịch bản 2 — "Sếp báo server sập"

**Vai:** Sếp Hùng, nam khoảng 30–45 tuổi. **Giọng:** gấp, chuyên nghiệp, hơi căng thẳng. Âm nền: văn phòng.

| File | Câu thoại | Gợi ý cách đọc |
| --- | --- | --- |
| `boss_1.wav` | Alo, em nghe máy được không? | Nhanh, hơi vội |
| *(người dùng trả lời)* | | |
| `boss_2.wav` | Server bên mình vừa gặp sự cố, cần em kiểm tra ngay. | Rõ ràng, nhấn "ngay" |
| `boss_3.wav` | Em có thể về máy tính trong ít phút nữa không? | Hỏi, chờ câu trả lời |
| *(người dùng trả lời)* | | |
| `boss_4.wav` | Ừ, anh chờ em. Cảm ơn nhé. | Nhẹ nhõm hơn |
| `boss_5.wav` | Có gì cập nhật thì gọi lại cho anh. | Kết thúc cuộc gọi |

## Kịch bản 3 — "Chủ trọ đòi tiền nhà"

**Vai:** Cô chủ trọ, nữ khoảng 40–60 tuổi. **Giọng:** thẳng thắn, hơi khó chịu nhưng lịch sự.

| File | Câu thoại | Gợi ý cách đọc |
| --- | --- | --- |
| `landlord_1.wav` | Alo, cô gọi về tiền phòng tháng này. | Đi thẳng vào việc |
| *(người dùng trả lời)* | | |
| `landlord_2.wav` | Con thu xếp về gặp cô hôm nay nhé. | Đề nghị nhưng cương quyết |
| `landlord_3.wav` | Cô cần nói chuyện trực tiếp một chút. | Nghiêm |
| `landlord_4.wav` | Cô đợi con ở nhà trọ. | Chốt lại |

## Kịch bản 4 — "Lan (bạn thân)"

**Vai:** Lan, nữ khoảng 18–25 tuổi. **Giọng:** thân mật, hơi bồn chồn. Âm nền: quán cà phê.

| File | Câu thoại | Gợi ý cách đọc |
| --- | --- | --- |
| `friend_1.wav` | Ê, cậu ra ngoài gặp mình một lát được không? | Thân, hơi nài |
| *(người dùng trả lời)* | | |
| `friend_2.wav` | Mình đang có chuyện gấp muốn hỏi cậu. | Nhỏ giọng hơn, có chuyện |
| `friend_3.wav` | Ra chỗ cũ nhé, mình đợi. | Chốt hẹn |

## Được sửa câu cho tự nhiên hơn

Người đọc có thể đổi chữ cho hợp giọng vùng miền của mình, ví dụ "về liền đi" thành "về liền nghen", hoặc thêm "nè", "á", "ha". Khi đó **sửa `text` của câu đó** trong `assets/scenarios/scenarios.json` cho khớp lời đã đọc, vì màn chi tiết kịch bản hiện chữ của từng câu. Có thể sửa thêm `seconds` (thời lượng câu, làm tròn giây) và `estimatedSeconds` của kịch bản.

## Sau khi chép file vào

1. Chạy `flutter test`: có test kiểm tra đủ file audio mẫu.
2. Mở app, vào combo dùng kịch bản đó, bấm **Xem thử cuộc gọi**, trả lời và nói thử xem người gọi có chờ đúng lượt không.
3. Commit riêng các file giọng, ghi rõ trong mô tả là người đọc đã đồng ý.
