# Case Study 2 - Task Manager

- MSSV: KHMT2411006
- Họ tên: Đinh Nguyễn Hoàng Minh

Ứng dụng quản lý và giao việc theo nhóm: người dùng tạo công việc, giao cho nhiều người, chia sẻ với quyền chỉ xem hoặc chỉnh sửa, nhận thông báo trong ứng dụng và qua email.

## Công nghệ

| Thành phần | Công nghệ |
| --- | --- |
| Ứng dụng di động | Flutter (thư mục `TaskManager`) |
| Máy chủ API | Node.js, Express 5 (thư mục `api`) |
| Cơ sở dữ liệu | MongoDB Atlas, Mongoose |
| Xác thực | JWT, bcryptjs |
| Email | Nodemailer (SMTP) |
| Kiểm thử | node:test (backend), flutter_test (ứng dụng) |

## Chức năng

- **Tài khoản:** đăng ký, đăng nhập, tự đăng nhập lại, xem và sửa họ tên, đổi mật khẩu.
- **Công việc:** thêm, sửa, xóa, đổi trạng thái (cần làm, đang làm, hoàn thành), mức ưu tiên, ngày bắt đầu và hạn.
- **Giao việc:** giao cho một hoặc nhiều người, đặt người phụ trách chính, hủy giao việc.
- **Chia sẻ:** chia sẻ với quyền viewer hoặc editor, đổi quyền, thu hồi.
- **Phân quyền:** kiểm tra ở backend cho mọi thao tác (xem bảng bên dưới).
- **Thông báo trong ứng dụng:** khi được giao việc, được chia sẻ, đổi quyền, thu hồi quyền, đổi trạng thái hoặc hạn; chuông có số chưa đọc; đánh dấu đã đọc.
- **Email:** gửi khi giao việc, chia sẻ, đổi hạn và hoàn thành; lưu lịch sử gửi (pending, sent, failed) và cho phép gửi lại.
- **Tìm kiếm, lọc, sắp xếp:** tìm theo tên; lọc theo trạng thái, mức ưu tiên, người phụ trách; sắp xếp theo hạn, ngày tạo, tên, ưu tiên, trạng thái.
- **Thống kê:** số việc theo trạng thái, việc được giao và phụ trách, việc quá hạn và sắp đến hạn.

## Phân quyền

| Hành động | Người tạo | Editor | Người được giao | Viewer |
| --- | --- | --- | --- | --- |
| Xem | ✓ | ✓ | ✓ | ✓ |
| Sửa thông tin | ✓ | ✓ | - | - |
| Đổi trạng thái | ✓ | ✓ | ✓ | - |
| Xóa | ✓ | - | - | - |
| Giao việc, chia sẻ, xem lịch sử email | ✓ | - | - | - |

## Cấu trúc thư mục

```
api/            Máy chủ Node.js (src/models, controllers, routes, middleware, services, tests)
TaskManager/    Ứng dụng Flutter (lib/models, screens, services, widgets)
```

## Cài đặt và chạy backend

Yêu cầu: Node.js bản LTS và một cụm MongoDB Atlas (hoặc MongoDB cài trên máy).

```bash
cd api
npm install
cp .env.example .env     # Windows PowerShell: Copy-Item .env.example .env
```

Điền các giá trị trong `.env`:

| Khóa | Ý nghĩa |
| --- | --- |
| `PORT` | Cổng máy chủ, mặc định 3000 |
| `MONGO_URI` | Chuỗi kết nối MongoDB |
| `JWT_SECRET` | Chuỗi bí mật ký JWT |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM` | Cấu hình gửi email (Gmail dùng mật khẩu ứng dụng, hoặc Mailtrap để thử) |
| `EMAIL_ENABLED` | Đặt `false` để tắt gửi email khi chạy thử |

Chạy máy chủ:

```bash
npm run dev      # tự khởi động lại khi sửa code
```

Kiểm tra: mở `http://localhost:3000/api/health`, kết quả `{"status":"ok"}`.

Lưu ý: không đưa file `.env` lên GitHub.

## Chạy ứng dụng Flutter

1. Mở thư mục `TaskManager` bằng Android Studio và chạy `Pub get`.
2. Địa chỉ API nằm trong `lib/utils/constants.dart`:
    - Máy ảo Android: `http://10.0.2.2:3000/api` (mặc định).
    - Điện thoại thật: đổi `10.0.2.2` thành địa chỉ IP của máy tính, điện thoại và máy tính cùng mạng Wi-Fi.
3. Bật backend rồi bấm Run.

## API chính

| Nhóm | Đường dẫn |
| --- | --- |
| Tài khoản | `POST /auth/register`, `POST /auth/login`, `GET /auth/me`, `PUT /auth/profile`, `PUT /auth/change-password` |
| Người dùng | `GET /users/search?q=`, `GET /users/:id` |
| Công việc | `GET /tasks` (scope, status, priority, q, assigneeId, sortBy, order), `POST /tasks`, `GET/PUT/DELETE /tasks/:id`, `PATCH /tasks/:id/status` |
| Giao việc | `GET/POST /tasks/:id/assignees`, `PATCH/DELETE /tasks/:id/assignees/:userId` |
| Chia sẻ | `GET/POST /tasks/:id/shares`, `PATCH/DELETE /tasks/:id/shares/:shareId` |
| Thông báo | `GET /notifications`, `GET /notifications/unread-count`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all` |
| Email | `GET /tasks/:id/email-logs`, `POST /email-logs/:id/retry` |
| Thống kê | `GET /statistics/tasks`, `GET /statistics/assignments`, `GET /statistics/deadlines` |

Mọi đường dẫn (trừ đăng ký và đăng nhập) cần header `Authorization: Bearer <token>`.

## Kiểm thử

Backend (bật máy chủ trước, nên đặt `EMAIL_ENABLED=false`):

```bash
cd api
npm test
```

Bộ test tích hợp gồm 17 nhóm kiểm tra: xác thực, kiểm tra dữ liệu đầu vào, CRUD, tìm kiếm, lọc, sắp xếp, giao việc, chia sẻ, phân quyền, thông báo, lịch sử email, thống kê, đổi mật khẩu và dọn dữ liệu. Bộ test tự tạo tài khoản riêng và tự xóa dữ liệu sau khi chạy.

Ứng dụng Flutter: chuột phải `TaskManager/test/task_filter_test.dart` trong Android Studio, chọn Run (hoặc `flutter test`).

## Quy trình làm việc với Git

Mỗi nhóm chức năng làm trên một nhánh riêng rồi gộp vào `main` bằng pull request: `feature/auth`, `feature/flutter-auth`, `feature/task-crud`, `feature/notifications`, `feature/email`.