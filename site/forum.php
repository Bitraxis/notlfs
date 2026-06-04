<?php
// =============================================================================
// NotLFS Simple Forum - Single File
// =============================================================================
// A minimal forum system with user login in a single PHP file.
// Database: MySQL with tables: users, forum_threads, forum_posts
//
// USAGE:
//   - View forum: forum.php
//   - View category: forum.php?category=1
//   - View thread: forum.php?thread=1
//   - New thread: forum.php?action=new&category=1
//   - Reply: forum.php?action=reply&thread=1
//   - Login: forum.php?action=login
//   - Logout: forum.php?action=logout
//

// =============================================================================
// CONFIGURATION
// =============================================================================

define('DB_HOST', 'localhost');
define('DB_USER', 'notlfs_user');
define('DB_PASS', 'your_password_here');
define('DB_NAME', 'notlfs_forum');

// Start session
session_start();

// =============================================================================
// DATABASE SETUP
// =============================================================================

function db_connect() {
    static $conn = null;
    if (!$conn) {
        $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
        if ($conn->connect_error) {
            die("Database connection failed: " . $conn->connect_error);
        }
    }
    return $conn;
}

// Initialize database tables if they don't exist
function init_db() {
    $db = db_connect();
    
    // Users table
    $db->query("
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(50) NOT NULL UNIQUE,
            password VARCHAR(255) NOT NULL,
            email VARCHAR(100),
            is_admin BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ");
    
    // Forum categories table
    $db->query("
        CREATE TABLE IF NOT EXISTS forum_categories (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            description TEXT,
            order_index INT DEFAULT 0
        )
    ");
    
    // Forum threads table
    $db->query("
        CREATE TABLE IF NOT EXISTS forum_threads (
            id INT AUTO_INCREMENT PRIMARY KEY,
            category_id INT NOT NULL,
            title VARCHAR(255) NOT NULL,
            slug VARCHAR(255) NOT NULL,
            content TEXT NOT NULL,
            created_by INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            view_count INT DEFAULT 0,
            reply_count INT DEFAULT 0,
            is_locked BOOLEAN DEFAULT FALSE,
            is_sticky BOOLEAN DEFAULT FALSE,
            FOREIGN KEY (category_id) REFERENCES forum_categories(id) ON DELETE CASCADE,
            FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
        )
    ");
    
    // Forum posts table
    $db->query("
        CREATE TABLE IF NOT EXISTS forum_posts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            thread_id INT NOT NULL,
            content TEXT NOT NULL,
            created_by INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (thread_id) REFERENCES forum_threads(id) ON DELETE CASCADE,
            FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
        )
    ");
    
    // Check if admin user exists, if not create one
    $result = $db->query("SELECT * FROM users WHERE username = 'admin'");
    if ($result->num_rows === 0) {
        // Default admin password: admin123 (CHANGE THIS!)
        $hash = password_hash('admin123', PASSWORD_DEFAULT);
        $db->query("INSERT INTO users (username, password, is_admin) VALUES ('admin', '$hash', TRUE)");
    }
    
    // Check if categories exist
    $result = $db->query("SELECT * FROM forum_categories");
    if ($result->num_rows === 0) {
        $db->query("INSERT INTO forum_categories (name, description, order_index) VALUES 
                   ('General', 'General discussion about NotLFS', 1),
                   ('Build Help', 'Help with building NotLFS systems', 2),
                   ('Package Requests', 'Request new packages', 3),
                   ('Showcase', 'Show off your NotLFS builds', 4)");
    }
}

// Call init_db on first load
init_db();

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function sanitize($str) {
    return htmlspecialchars($str ?? '', ENT_QUOTES, 'UTF-8');
}

function slugify($str) {
    $str = strtolower($str);
    $str = preg_replace('/[^a-z0-9\s-]/', '', $str);
    $str = preg_replace('/[\s-]+/', '-', $str);
    return trim($str, '-');
}

function is_logged_in() {
    return isset($_SESSION['user_id']);
}

function get_user() {
    if (!is_logged_in()) return null;
    $db = db_connect();
    $stmt = $db->prepare("SELECT * FROM users WHERE id = ?");
    $stmt->bind_param("i", $_SESSION['user_id']);
    $stmt->execute();
    $result = $stmt->get_result();
    return $result->fetch_assoc();
}

function is_admin() {
    $user = get_user();
    return $user && $user['is_admin'];
}

function redirect($url) {
    header("Location: $url");
    exit;
}

// Simple markdown to HTML
function markdown($text) {
    $text = preg_replace('/^# (.*$)/m', '<h1>$1</h1>', $text);
    $text = preg_replace('/^## (.*$)/m', '<h2>$1</h2>', $text);
    $text = preg_replace('/\*\*(.*?)\*\*/', '<strong>$1</strong>', $text);
    $text = preg_replace('/\*(.*?)\*/', '<em>$1</em>', $text);
    $text = preg_replace('/\[(.*?)\]\((.*?)\)/', '<a href="$2">$1</a>', $text);
    $text = preg_replace('/```(.*?)\n(.*?)```/s', '<pre><code>$2</code></pre>', $text);
    $text = preg_replace('/`(.*?)`/', '<code>$1</code>', $text);
    $text = preg_replace('/^\* (.*$)/m', '<li>$1</li>', $text);
    $text = '<p>' . str_replace("\n\n", '</p><p>', $text) . '</p>';
    return $text;
}

// =============================================================================
// FORUM FUNCTIONS
// =============================================================================

function get_categories() {
    $db = db_connect();
    $result = $db->query("SELECT * FROM forum_categories ORDER BY order_index");
    return $result->fetch_all(MYSQLI_ASSOC);
}

function get_category($id) {
    $db = db_connect();
    $stmt = $db->prepare("SELECT * FROM forum_categories WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    return $result->fetch_assoc();
}

function get_threads($category_id = null, $limit = null, $offset = 0) {
    $db = db_connect();
    $query = "SELECT t.*, c.name as category_name, u.username as author_name FROM forum_threads t 
              JOIN forum_categories c ON t.category_id = c.id 
              JOIN users u ON t.created_by = u.id";
    $params = [];
    $types = "";
    
    if ($category_id !== null) {
        $query .= " WHERE t.category_id = ?";
        $params[] = $category_id;
        $types .= "i";
    }
    
    $query .= " ORDER BY t.is_sticky DESC, t.updated_at DESC";
    
    if ($limit !== null) {
        $query .= " LIMIT ?";
        $params[] = $limit;
        $types .= "i";
    }
    
    if ($offset > 0) {
        $query .= " OFFSET ?";
        $params[] = $offset;
        $types .= "i";
    }
    
    $stmt = $db->prepare($query);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    return $result->fetch_all(MYSQLI_ASSOC);
}

function get_thread($id) {
    $db = db_connect();
    $stmt = $db->prepare("SELECT t.*, c.name as category_name, u.username as author_name FROM forum_threads t 
              JOIN forum_categories c ON t.category_id = c.id 
              JOIN users u ON t.created_by = u.id WHERE t.id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    return $result->fetch_assoc();
}

function get_posts($thread_id) {
    $db = db_connect();
    $stmt = $db->prepare("SELECT p.*, u.username as author_name FROM forum_posts p 
              JOIN users u ON p.created_by = u.id WHERE p.thread_id = ? ORDER BY p.created_at");
    $stmt->bind_param("i", $thread_id);
    $stmt->execute();
    $result = $stmt->get_result();
    return $result->fetch_all(MYSQLI_ASSOC);
}

function create_thread($category_id, $title, $content, $user_id) {
    $db = db_connect();
    $slug = slugify($title);
    $stmt = $db->prepare("INSERT INTO forum_threads (category_id, title, slug, content, created_by) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("isssi", $category_id, $title, $slug, $content, $user_id);
    $stmt->execute();
    return $db->insert_id;
}

function create_post($thread_id, $content, $user_id) {
    $db = db_connect();
    $stmt = $db->prepare("INSERT INTO forum_posts (thread_id, content, created_by) VALUES (?, ?, ?)");
    $stmt->bind_param("isi", $thread_id, $content, $user_id);
    $stmt->execute();
    
    // Update thread reply count
    $db->query("UPDATE forum_threads SET reply_count = reply_count + 1, updated_at = CURRENT_TIMESTAMP WHERE id = $thread_id");
    return $db->insert_id;
}

function increment_view_count($thread_id) {
    $db = db_connect();
    $db->query("UPDATE forum_threads SET view_count = view_count + 1 WHERE id = $thread_id");
}

function count_threads($category_id = null) {
    $db = db_connect();
    $query = "SELECT COUNT(*) as count FROM forum_threads";
    if ($category_id !== null) {
        $query .= " WHERE category_id = $category_id";
    }
    $result = $db->query($query);
    $row = $result->fetch_assoc();
    return $row['count'];
}

// =============================================================================
// ACTION HANDLERS
// =============================================================================

$action = $_GET['action'] ?? '';
$category_id = $_GET['category'] ?? null;
$thread_id = $_GET['thread'] ?? null;
$page = $_GET['page'] ?? 1;

// Handle logout
if ($action === 'logout') {
    session_destroy();
    redirect('forum.php');
}

// Handle login
if ($action === 'login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    $db = db_connect();
    $stmt = $db->prepare("SELECT * FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    
    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['user_id'] = $user['id'];
        redirect('forum.php');
    } else {
        $error = "Invalid username or password";
    }
}

// Handle register
if ($action === 'register' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $email = trim($_POST['email'] ?? '');
    
    if (empty($username) || empty($password)) {
        $error = "Username and password are required";
    } else {
        $db = db_connect();
        $stmt = $db->prepare("SELECT * FROM users WHERE username = ?");
        $stmt->bind_param("s", $username);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $error = "Username already exists";
        } else {
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $db->prepare("INSERT INTO users (username, password, email) VALUES (?, ?, ?)");
            $stmt->bind_param("sss", $username, $hash, $email);
            $stmt->execute();
            redirect("forum.php?action=login&success=Registration successful. Please login.");
        }
    }
}

// Handle new thread
if ($action === 'new' && $_SERVER['REQUEST_METHOD'] === 'POST' && is_logged_in()) {
    $category_id = $_POST['category_id'] ?? 0;
    $title = trim($_POST['title'] ?? '');
    $content = $_POST['content'] ?? '';
    $user_id = $_SESSION['user_id'];
    
    if (empty($title) || empty($content)) {
        $error = "Title and content are required";
    } else {
        $thread_id = create_thread($category_id, $title, $content, $user_id);
        redirect("forum.php?thread=$thread_id");
    }
}

// Handle reply
if ($action === 'reply' && $_SERVER['REQUEST_METHOD'] === 'POST' && is_logged_in()) {
    $thread_id = $_POST['thread_id'] ?? 0;
    $content = $_POST['content'] ?? '';
    $user_id = $_SESSION['user_id'];
    
    if (empty($content)) {
        $error = "Content is required";
    } else {
        create_post($thread_id, $content, $user_id);
        redirect("forum.php?thread=$thread_id");
    }
}

// Increment view count when viewing a thread
if ($thread_id && $action !== 'reply') {
    increment_view_count($thread_id);
}

// =============================================================================
// HTML OUTPUT
// =============================================================================

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NotLFS Forum<?php echo $thread_id ? " - Thread" : ($category_id ? " - Category" : ""); ?></title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; max-width: 900px; margin: 0 auto; padding: 20px; color: #333; }
        h1, h2, h3 { color: #0066cc; }
        h1 { border-bottom: 2px solid #0066cc; padding-bottom: 10px; }
        a { color: #0066cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
        pre { background: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; border: 1px solid #ddd; }
        code { background: #f8f8f8; padding: 2px 5px; border-radius: 3px; }
        .nav { margin: 20px 0; }
        .nav a { margin-right: 15px; }
        .user-info { float: right; }
        .content { margin: 20px 0; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 5px; font-weight: bold; }
        .form-group input, .form-group textarea, .form-group select { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        .form-group textarea { min-height: 200px; resize: vertical; }
        .btn { padding: 8px 15px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; }
        .btn:hover { background: #0055aa; }
        .btn-danger { background: #cc0000; }
        .btn-danger:hover { background: #aa0000; }
        .error { color: #cc0000; }
        .success { color: #009900; }
        hr { border: none; border-top: 1px solid #eee; margin: 20px 0; }
        
        /* Forum specific styles */
        .category { margin-bottom: 2em; }
        .category h3 { background: #f8f8f8; padding: 10px; border-bottom: 1px solid #ddd; }
        .thread-list { margin: 10px 0; }
        .thread { border-bottom: 1px solid #eee; padding: 10px 0; }
        .thread:last-child { border-bottom: none; }
        .thread-title { font-size: 1.1em; font-weight: bold; }
        .thread-meta { color: #666; font-size: 0.9em; margin: 5px 0; }
        .thread-stats { display: inline-block; margin-right: 15px; }
        .post { border-bottom: 1px solid #eee; padding: 15px 0; margin: 10px 0; }
        .post:last-child { border-bottom: none; }
        .post-header { display: flex; justify-content: space-between; margin-bottom: 10px; }
        .post-author { font-weight: bold; }
        .post-date { color: #666; font-size: 0.9em; }
        .post-content { margin: 10px 0; }
        .reply-form { margin: 20px 0; }
        .pagination { margin: 20px 0; text-align: center; }
        .pagination a, .pagination span { display: inline-block; padding: 5px 10px; margin: 0 5px; border: 1px solid #ddd; border-radius: 3px; }
        .pagination .current { background: #0066cc; color: white; border-color: #0066cc; }
        .sticky { background: #fff8e1; }
        .locked { color: #666; }
        
        @media (max-width: 768px) { 
            .user-info { float: none; margin-top: 10px; } 
            .post-header { flex-direction: column; }
        }
    </style>
</head>
<body>
    <header>
        <h1><a href="forum.php">NotLFS Forum</a></h1>
        <nav class="nav">
            <a href="forum.php">Forum</a>
            <?php if (is_logged_in()): ?>
                <a href="forum.php?action=new">New Thread</a>
            <?php endif; ?>
            <span class="user-info">
                <?php if (is_logged_in()): ?>
                    <?php $user = get_user(); echo "Hello, " . sanitize($user['username']); ?> |
                    <a href="forum.php?action=logout">Logout</a>
                <?php else: ?>
                    <a href="forum.php?action=login">Login</a>
                    <a href="forum.php?action=register">Register</a>
                <?php endif; ?>
            </span>
        </nav>
    </header>
    
    <main class="content">
        <?php if (isset($error)): ?>
            <p class="error"><?php echo sanitize($error); ?></p>
        <?php endif; ?>
        
        <?php if (isset($_GET['success'])): ?>
            <p class="success"><?php echo sanitize($_GET['success']); ?></p>
        <?php endif; ?>
        
        <?php
        // =========================================================================
        // DISPLAY CONTENT BASED ON ACTION
        // =========================================================================
        
        if ($action === 'login'):
            // Login form
            echo "<h2>Login</h2>\n";
            echo "<form method='post' action='forum.php?action=login'>\n";
            echo "    <div class='form-group'>\n";
            echo "        <label for='username'>Username:</label>\n";
            echo "        <input type='text' id='username' name='username' required>\n";
            echo "    </div>\n";
            echo "    <div class='form-group'>\n";
            echo "        <label for='password'>Password:</label>\n";
            echo "        <input type='password' id='password' name='password' required>\n";
            echo "    </div>\n";
            echo "    <button type='submit' class='btn'>Login</button>\n";
            echo "</form>\n";
            echo "<p>Don't have an account? <a href='forum.php?action=register'>Register</a></p>\n";
            
        elseif ($action === 'register'):
            // Registration form
            echo "<h2>Register</h2>\n";
            echo "<form method='post' action='forum.php?action=register'>\n";
            echo "    <div class='form-group'>\n";
            echo "        <label for='username'>Username:</label>\n";
            echo "        <input type='text' id='username' name='username' required>\n";
            echo "    </div>\n";
            echo "    <div class='form-group'>\n";
            echo "        <label for='password'>Password:</label>\n";
            echo "        <input type='password' id='password' name='password' required>\n";
            echo "    </div>\n";
            echo "    <div class='form-group'>\n";
            echo "        <label for='email'>Email (optional):</label>\n";
            echo "        <input type='email' id='email' name='email'>\n";
            echo "    </div>\n";
            echo "    <button type='submit' class='btn'>Register</button>\n";
            echo "</form>\n";
            echo "<p>Already have an account? <a href='forum.php?action=login'>Login</a></p>\n";
            
        elseif ($action === 'new'):
            // New thread form
            if (!is_logged_in()) {
                echo "<p class='error'>You must be logged in to create a thread.</p>\n";
                echo "<p><a href='forum.php?action=login'>Login</a></p>\n";
            } else {
                echo "<h2>New Thread</h2>\n";
                echo "<form method='post' action='forum.php?action=new'>\n";
                echo "    <div class='form-group'>\n";
                echo "        <label for='category_id'>Category:</label>\n";
                echo "        <select id='category_id' name='category_id' required>\n";
                $categories = get_categories();
                foreach ($categories as $cat) {
                    echo "            <option value='" . $cat['id'] . "'>" . sanitize($cat['name']) . "</option>\n";
                }
                echo "        </select>\n";
                echo "    </div>\n";
                echo "    <div class='form-group'>\n";
                echo "        <label for='title'>Title:</label>\n";
                echo "        <input type='text' id='title' name='title' required>\n";
                echo "    </div>\n";
                echo "    <div class='form-group'>\n";
                echo "        <label for='content'>Content (Markdown supported):</label>\n";
                echo "        <textarea id='content' name='content' required></textarea>\n";
                echo "    </div>\n";
                echo "    <button type='submit' class='btn'>Create Thread</button>\n";
                echo "</form>\n";
            }
            
        elseif ($thread_id):
            // View thread
            $thread = get_thread($thread_id);
            if (!$thread) {
                echo "<p class='error'>Thread not found.</p>\n";
            } else {
                // Display thread
                echo "<div class='thread'>\n";
                echo "    <h2 class='thread-title'>" . sanitize($thread['title']) . "</h2>\n";
                echo "    <div class='thread-meta'>\n";
                echo "        <span class='thread-stats'>Started by " . sanitize($thread['author_name']) . "</span>\n";
                echo "        <span class='thread-stats'>" . $thread['view_count'] . " views</span>\n";
                echo "        <span class='thread-stats'>" . $thread['reply_count'] . " replies</span>\n";
                echo "        <span class='thread-stats'>In: <a href='forum.php?category=" . $thread['category_id'] . "'>" . sanitize($thread['category_name']) . "</a></span>\n";
                echo "    </div>\n";
                echo "</div>\n";
                
                // Display posts
                $posts = get_posts($thread_id);
                foreach ($posts as $post) {
                    echo "<div class='post'>\n";
                    echo "    <div class='post-header'>\n";
                    echo "        <span class='post-author'>" . sanitize($post['author_name']) . "</span>\n";
                    echo "        <span class='post-date'>" . date('M j, Y g:i a', strtotime($post['created_at'])) . "</span>\n";
                    echo "    </div>\n";
                    echo "    <div class='post-content'>\n";
                    echo markdown($post['content']);
                    echo "    </div>\n";
                    echo "</div>\n";
                }
                
                // Reply form
                if (is_logged_in()) {
                    echo "<div class='reply-form'>\n";
                    echo "    <h3>Reply</h3>\n";
                    echo "    <form method='post' action='forum.php?action=reply'>\n";
                    echo "        <input type='hidden' name='thread_id' value='$thread_id'>\n";
                    echo "        <div class='form-group'>\n";
                    echo "            <label for='content'>Your reply:</label>\n";
                    echo "            <textarea id='content' name='content' required></textarea>\n";
                    echo "        </div>\n";
                    echo "        <button type='submit' class='btn'>Post Reply</button>\n";
                    echo "    </form>\n";
                    echo "</div>\n";
                } else {
                    echo "<p><a href='forum.php?action=login'>Login</a> to reply.</p>\n";
                }
            }
            
        elseif ($category_id):
            // View category
            $category = get_category($category_id);
            if (!$category) {
                echo "<p class='error'>Category not found.</p>\n";
            } else {
                echo "<h2>Category: " . sanitize($category['name']) . "</h2>\n";
                echo "<p>" . sanitize($category['description']) . "</p>\n";
                
                // Pagination
                $total_threads = count_threads($category_id);
                $total_pages = ceil($total_threads / 10);
                $page = max(1, min($page, $total_pages));
                $offset = ($page - 1) * 10;
                
                // Display threads
                $threads = get_threads($category_id, 10, $offset);
                if (empty($threads)) {
                    echo "<p>No threads in this category.</p>\n";
                } else {
                    echo "<div class='thread-list'>\n";
                    foreach ($threads as $thread) {
                        echo "<div class='thread'>\n";
                        echo "    <div class='thread-title'>\n";
                        if ($thread['is_sticky']) echo "<span class='sticky'>[Sticky] </span>";
                        if ($thread['is_locked']) echo "<span class='locked'>[Locked] </span>";
                        echo "<a href='forum.php?thread=" . $thread['id'] . "'>" . sanitize($thread['title']) . "</a>\n";
                        echo "    </div>\n";
                        echo "    <div class='thread-meta'>\n";
                        echo "        <span class='thread-stats'>Started by " . sanitize($thread['author_name']) . "</span>\n";
                        echo "        <span class='thread-stats'>" . $thread['reply_count'] . " replies</span>\n";
                        echo "        <span class='thread-stats'>" . date('M j', strtotime($thread['created_at'])) . "</span>\n";
                        echo "    </div>\n";
                        echo "</div>\n";
                    }
                    echo "</div>\n";
                    
                    // Pagination
                    if ($total_pages > 1) {
                        echo "<div class='pagination'>\n";
                        if ($page > 1) {
                            echo "<a href='forum.php?category=$category_id&page=" . ($page - 1) . "'>&laquo; Previous</a> ";
                        }
                        for ($i = 1; $i <= $total_pages; $i++) {
                            if ($i == $page) {
                                echo "<span class='current'>$i</span> ";
                            } else {
                                echo "<a href='forum.php?category=$category_id&page=$i'>$i</a> ";
                            }
                        }
                        if ($page < $total_pages) {
                            echo "<a href='forum.php?category=$category_id&page=" . ($page + 1) . "'>Next &raquo;</a>\n";
                        }
                        echo "</div>\n";
                    }
                }
                
                if (is_logged_in()) {
                    echo "<p><a href='forum.php?action=new&category=$category_id' class='btn'>New Thread</a></p>\n";
                }
            }
            
        else:
            // View all categories
            echo "<h2>NotLFS Discussion Forum</h2>\n";
            echo "<p>Welcome to the NotLFS discussion forum. Ask questions, share your builds, and help others.</p>\n";
            
            $categories = get_categories();
            foreach ($categories as $cat) {
                $thread_count = count_threads($cat['id']);
                echo "<div class='category'>\n";
                echo "    <h3><a href='forum.php?category=" . $cat['id'] . "'>" . sanitize($cat['name']) . "</a></h3>\n";
                echo "    <p>" . sanitize($cat['description']) . "</p>\n";
                echo "    <p class='thread-meta'>$thread_count threads</p>\n";
                echo "</div>\n";
            }
        
        ?>
    </main>
    
    <footer>
        <hr>
        <p>NotLFS Forum - A simple discussion forum for the NotLFS project</p>
    </footer>
</body>
</html>