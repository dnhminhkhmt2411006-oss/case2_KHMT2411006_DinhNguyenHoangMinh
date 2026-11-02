exports.notFound = (req, res) =>
  res.status(404).json({ message: 'Không tìm thấy đường dẫn' });

// eslint-disable-next-line no-unused-vars
exports.errorHandler = (err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ message: 'Lỗi máy chủ' });
};