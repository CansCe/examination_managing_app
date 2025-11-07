export const errorHandler = (err, req, res, next) => {
  console.error('\n╔══════════════════════════════════════════════════════════╗');
  console.error('║  ✗ CHAT SERVICE - Error                               ║');
  console.error('╚══════════════════════════════════════════════════════════╝');
  console.error('Error:', err);
  console.error('Path:', req.originalUrl);
  console.error('Method:', req.method);

  // Default error
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(statusCode).json({
    success: false,
    service: 'CHAT SERVICE',
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};

export const notFound = (req, res, next) => {
  res.status(404).json({
    success: false,
    service: 'CHAT SERVICE',
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`
  });
};

