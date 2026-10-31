require('dotenv').config();
const app = require('./app');
const connectDB = require('./config/database');

connectDB()
  .then(() => app.listen(process.env.PORT, () =>
    console.log(`API chạy tại http://localhost:${process.env.PORT}`)))
  .catch(err => {
    console.error('Lỗi kết nối MongoDB:', err.message);
    process.exit(1);
  });