CREATE DATABASE IF NOT EXISTS mydatabase;
USE mydatabase;
CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    position VARCHAR(100),
    salary INT
);

INSERT INTO employees (name, position, salary) VALUES 
('Alice', 'Engineer', 70000),
('Bob', 'Manager', 85000),
('Charlie', 'Analyst', 60000);

