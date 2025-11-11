
const mysql = require('mysql2');
const dotenv = require('dotenv');

// .env 파일에서 DB 정보 로드
dotenv.config();

// DB 연결 설정
const connection = mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
});

// 1. DB 연결 시도
connection.connect(err => {
    if (err) {
        console.error('DB 연결 실패 🚨');
        console.error('------------------------------------------------');
        console.error('.env 파일의 DB_HOST, DB_USER, DB_PASSWORD, DB_NAME 정보가 정확한지 확인하세요.');
        console.error('RDS 보안 그룹에서 이 EC2의 IP를 허용했는지도 확인하세요.');
        console.error('------------------------------------------------');
        console.error('원본 오류:', err.message);
        return;
    }
    
    console.log('DB 연결 성공! ✅');

    // 2. 테이블 생성 쿼리
    const createTableQuery = `
        CREATE TABLE IF NOT EXISTS guestbook (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    `;

    // 3. 쿼리 실행
    connection.query(createTableQuery, (err, result) => {
        if (err) {
            console.error('테이블 생성 실패 🚨', err);
        } else {
            console.log("'guestbook' 테이블이 성공적으로 준비되었습니다. ✅");
            console.log("이제 'node server.js' 또는 'pm2 start server.js'로 메인 앱을 실행하세요.");
        }
        
        // 4. DB 연결 종료
        connection.end();
    });
});
