# Hướng Dẫn Tổng Hợp: COLOSSEUM - Đấu Trường Agent (Day 26)

Đây là tài liệu tổng hợp (được đúc kết từ tất cả các file README, RULES và mô tả hệ thống) giúp bạn có một cái nhìn toàn cảnh và chiến lược tốt nhất để giải quyết trọn vẹn 3 Task trong lab này.

---

## 1. Bức Tranh Toàn Cảnh
Bạn đang xây dựng **backend của một VLearn tutor** (gia sư ảo) qua giao thức MCP/A2A. Hệ thống dữ liệu mà gia sư này truy xuất chứa những thông tin bị sai lệch, thiếu nhất quán (replica drift, tài liệu nhiễu, lỗi mờ...). 

Bạn sẽ thi đấu với các bot (rookie, operator, adversary) hoặc người chơi khác. Trong mỗi lượt đấu, bạn phải thực hiện cả 3 nhiệm vụ:
- **ATTACK (`deck/`)**: Tung ra các câu hỏi và bộ lọc (mutation) bị bóp méo để lừa đối thủ trả lời sai.
- **DEFEND (`agent/`)**: Khi bị đối thủ tấn công, hệ thống của bạn phải suy luận, truy vấn dữ liệu, kiểm chứng và trả lời **có dẫn chứng (grounded)** và phải tuân thủ an toàn (guardrails).
- **PROSECUTE (`eval/`)**: Đóng vai trò công tố viên, soi trace (lịch sử hành động) của đối thủ để bắt lỗi.

> [!IMPORTANT]
> **Quy luật tối cao:** "Không chỉ ra được thì không có sát thương" (No claim, no damage). 
> Nếu đối thủ đánh trúng bạn nhưng họ không chỉ ra được bằng chứng (claim) hợp lệ, bạn không mất điểm. Ngược lại, nếu bạn tố cáo sai, bạn sẽ bị phạt điểm (0.8 × trọng số lỗi).

---

## 2. Chuẩn Bị & Cài Đặt (Quan trọng)
Dữ liệu của thế giới (corpus) **không có sẵn trong repo này**. Bạn cần tải từ phần Releases:
```bash
# 1. Tải corpus
gh release download world-df8c55dabb35 --pattern '*.zip'
unzip colosseum-world-df8c55dabb35.zip  # Chú ý giải nén sao cho có file kit/world/<world_id>/manifest.json
rm colosseum-world-df8c55dabb35.zip

# 2. Cài đặt và kiểm tra
make install
make doctor # Kiểm tra sẵn sàng, nó phải báo nhận diện được số pages.

# 3. Chạy thử
make spar BOT=rookie  # Đấu với bot dễ nhất
make ui               # Mở giao diện xem trận đấu
```

---

## 3. Chiến Lược Làm Bài (3 Tasks)

### TASK 1: ATTACK (`deck/`) - Tạo bộ bài tấn công
Bạn cần cấu hình tối thiểu 14 lá bài (10 lá tấn công, 4 lá rỗng) trong file `deck.json`. 
- **Quy tắc bộ bài hợp lệ:** Phải có đủ 3 lớp MCP, 3 lớp A2A, 2 lớp gateway và phủ ít nhất 6/9 loại lỗi (class). 
- **Chiến lược hay nhất:** Lựa chọn `ask` (câu hỏi) sao cho việc làm sai lệch dữ liệu (`mutation`) gây ra ảnh hưởng thực sự lên câu trả lời. 
  - *Ví dụ tốt:* Dùng `replica_flip` cho câu hỏi `which_day_covers` vì số frame của các bài giảng khác nhau giữa các replica. Đối thủ không check replica sẽ lấy nhầm thông tin.
  - *Ví dụ tồi:* Dùng `replica_flip` cho `citation_for` vì trích dẫn URL ở cả 2 replica là giống hệt nhau. Lá bài của bạn sẽ vô dụng.
- **Kiểm tra bộ bài:** Hãy chạy lệnh `make validate` thường xuyên để đảm bảo bộ bài của bạn đúng chuẩn.

### TASK 3: DEFEND (`agent/`) - Phòng Thủ
Bạn làm chủ thư mục này, bao gồm 5 file. Đừng gộp logic lung tung, mỗi file có một nhiệm vụ riêng, và sai lầm lớn nhất là vi phạm **Authority** và **Enforcement**.

1. **`gateway.py` (Trọng tâm nhất):** 
   - Nhiệm vụ: Chấp nhận (ADMIT), Phân quyền (AUTHORIZE), Định tuyến (ROUTE), Tính phí (BUDGET). Hàm `decide` ở đây là lớp bảo vệ thực thi.
   - **CẤM KỴ:** Hàm `decide` phải chạy đồng bộ (synchronous), thời gian chạy `< 250ms`, và **Tuyệt đối không có I/O hoặc network**. Nếu bị crash hoặc timeout, bạn ăn trọn combo lỗi nặng nhất (`enforcement_failure`, `authority_exceeded`).
2. **`strategy.py`:** Nơi chứa chính sách (chọn replica nào, giới hạn cache, ủy quyền A2A). Nó quyết định giúp `gateway` tiết kiệm budget.
3. **`guardrails.py`:** Nơi duyệt câu trả lời trước khi nói ra. Phải thực thi `check_grounding` (đảm bảo nói có sách, mách có chứng) và `abstention_policy` (biết từ chối đúng lúc thay vì đoán bừa).
4. **`prompt.md`:** Chứa prompt của hệ thống, hướng dẫn agent cách suy luận và phản hồi. (Bảo vệ bạn khỏi `guardrail_breach`).
5. **`telemetry.py`:** Dùng để ghi log quá trình suy luận. Trọng tài sẽ xóa file này đi trước khi đưa trace cho đối thủ.

### TASK 2: PROSECUTE (`eval/`) - Công Tố Viên
Viết logic trong `eval/prosecute.py` để tìm lỗi trong trace của đối phương.
- Bạn có quyền submit tối đa 4 claims mỗi lượt.
- Bạn phải tuân thủ chuẩn claim: `evt:XXXX`, `answer.span:X`, v.v...
- **Kinh tế học của việc bắt lỗi:** Break-even (điểm hòa vốn) của một claim luôn là **44.4%** tự tin cho bất kì class nào, bất kể lỗi nặng hay nhẹ. 
  - **Lời khuyên:** Đừng "nhắm mắt bắn bừa" vào các lỗi nặng (weight 10) nếu bạn không chắc. Bạn hãy tố cáo những lỗi bạn có thể chỉ mặt đặt tên sự kiện rõ ràng nhất. Xem kỹ code hàm `detect_enforcement_failure` đã được cho sẵn để học cách viết các hàm detector khác.

---

## 4. Những Điều Cấm Kỵ (Gây loại bài thi)
1. **Không sửa thư mục `kit/`, `bots/`, `fixtures/`.** Bất kỳ thay đổi nào sẽ làm thay đổi hash file và bài thi của bạn lập tức bị từ chối.
2. **Chỉ dùng Standard Library.** Không dùng thư viện ngoài. Đặc biệt bị cấm: `socket`, `requests`, `subprocess`, `multiprocessing`, `os.system`... Mã của bạn chạy trong kernel sandbox.
3. **Đừng thử rình rập thư mục của đội khác:** Sandbox sẽ chặn lại, lưu log vi phạm toàn vẹn và bạn mất điểm trực tiếp.

---

## 5. Quy Trình Submit Nộp Bài
Khi bạn đã tự tin với thiết kế của mình, hãy chạy thử nghiệm toàn diện:
```bash
make test                    # Chạy conformance test, đảm bảo hệ thống làm việc đúng yêu cầu
make validate                # Đảm bảo deck hợp lệ
make submit TEAM=<tên-đội>   # Nộp bài, sẽ đóng gói thành file .bundle
```
File bundle ở `submissions/<tên-đội>.bundle` chính là thứ bạn dùng để thi đấu thức tế. Chúc bạn làm bài thật tốt!
