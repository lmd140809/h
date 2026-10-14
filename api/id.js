export default function handler(req, res) {
  const unben = req.query.unben || 'khong-co';
  console.log('Nhận ID:', unben);
  res.setHeader('Content-Type', 'text/plain');
  res.status(200).send('OK');
}
