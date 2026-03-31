function notFoundHandler(req, res) {
  res.status(404).json({
    message: "Resource not found",
    path: req.path,
    correlationId: req?.ctx?.correlationId
  });
}

module.exports = { notFoundHandler };
