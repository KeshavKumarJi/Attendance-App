DROP TABLE IF EXISTS attendance_records CASCADE;
DROP TABLE IF EXISTS attendance_sessions CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS sections CASCADE;
DROP TABLE IF EXISTS teachers CASCADE;

CREATE TABLE teachers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL
);

CREATE TABLE sections (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    enrollment_no VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    section_id INT REFERENCES sections(id) ON DELETE CASCADE,
    batch VARCHAR(10) CHECK (batch IN ('A', 'B')) NOT NULL
);

CREATE TABLE attendance_sessions (
    id SERIAL PRIMARY KEY,
    teacher_id INT REFERENCES teachers(id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(id) ON DELETE CASCADE,
    batch_type VARCHAR(10) CHECK (batch_type IN ('A', 'B', 'BOTH')) NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE attendance_records (
    id SERIAL PRIMARY KEY,
    session_id INT REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    student_id INT REFERENCES students(id) ON DELETE CASCADE,
    status VARCHAR(10) CHECK (status IN ('PRESENT', 'ABSENT', 'LEAVE')) NOT NULL,
    UNIQUE(session_id, student_id)
);

-- Seed Data (Password is 'password' for both)
INSERT INTO teachers (name, username, password_hash) VALUES 
('John Doe', 'john', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2EIO/uX7m6'),
('Jane Smith', 'jane', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2EIO/uX7m6');

INSERT INTO sections (name) VALUES ('T1'), ('T2');

DO $$
DECLARE
    i INT;
    sec_t1 INT;
    sec_t2 INT;
BEGIN
    SELECT id INTO sec_t1 FROM sections WHERE name = 'T1';
    SELECT id INTO sec_t2 FROM sections WHERE name = 'T2';
    
    FOR i IN 1..32 LOOP
        INSERT INTO students (enrollment_no, name, section_id, batch) VALUES ('T1A' || i, 'T1 Student A' || i, sec_t1, 'A');
        INSERT INTO students (enrollment_no, name, section_id, batch) VALUES ('T1B' || i, 'T1 Student B' || i, sec_t1, 'B');
        INSERT INTO students (enrollment_no, name, section_id, batch) VALUES ('T2A' || i, 'T2 Student A' || i, sec_t2, 'A');
        INSERT INTO students (enrollment_no, name, section_id, batch) VALUES ('T2B' || i, 'T2 Student B' || i, sec_t2, 'B');
    END LOOP;
END $$;
