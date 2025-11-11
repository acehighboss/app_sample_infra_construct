
// 1. 필요한 모듈 가져오기
const express = require('express');
const mysql = require('mysql2'); // RDS(MySQL)와 통신
const dotenv = require('dotenv'); // .env 파일에서 환경변수 로드
const path = require('path');

// 2. .env 파일 로드
dotenv.config();

// 3. Express 앱 생성 및 설정
const app = express();
const port = 3000; // 앱은 3000번 포트에서 실행됩니다.

// 템플릿 엔진으로 EJS 사용
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// POST 요청의 body(form data)를 파싱하기 위한 미들웨어
app.use(express.urlencoded({ extended: true }));

// 4. DB 연결 풀(Pool) 생성 (RDS 정보 사용)
// .env 파일에서 환경변수를 읽어옵니다.
const dbPool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
}).promise(); // .promise()를 사용하여 async/await 문법 지원

// 5. 라우트(Route) 설정

// GET / : 메인 페이지 (방명록 목록 표시)
app.get('/', async (req, res) => {
    try {
        const [rows] = await dbPool.query("SELECT id, name, message, created_at FROM guestbook ORDER BY created_at DESC");
        
        // index.ejs 템플릿을 렌더링하며 DB 결과(rows)를 전달
        res.render('index', { entries: rows });

    } catch (err) {
        console.error('DB 쿼리 오류:', err);
        res.status(500).send('DB 조회 중 오류가 발생했습니다. <br>' + err.message);
    }
});

// POST / : 새 글 등록 (폼 제출 처리)
app.post('/', async (req, res) => {
    const { name, message } = req.body; // 폼에서 전송된 데이터

    // 간단한 유효성 검사
    if (!name || !message) {
        return res.status(400).send('이름과 메시지를 모두 입력해야 합니다.');
    }

    try {
        const query = "INSERT INTO guestbook (name, message) VALUES (?, ?)";
        await dbPool.query(query, [name, message]);

        // 성공 시, 메인 페이지로 리다이렉트 (새로고침 시 중복 등록 방지)
        res.redirect('/');

    } catch (err) {
        console.error('DB 삽입 오류:', err);
        res.status(500).send('DB 저장 중 오류가 발생했습니다. <br>' + err.message);
    }
});

// 6. 서버 시작
app.listen(port, () => {
    console.log(`================================================`);
    console.log(`  방명록 앱이 http://localhost:${port} 에서 실행 중입니다.`);
    console.log(`  (EC2에서는 Public IP의 ${port} 포트로 접속)`);
    console.log(`================================================`);
    console.log(`DB 호스트: ${process.env.DB_HOST}`);
    console.log(`DB 이름: ${process.env.DB_NAME}`);
    console.log(`DB 사용자: ${process.env.DB_USER}`);
    console.log(`------------------------------------------------`);
});