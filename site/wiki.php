<?php
// =============================================================================
// NotLFS Simple Wiki - Single File
// =============================================================================
// A minimal wiki system with user login in a single PHP file.
// Database: MySQL with tables: users, wiki_pages
//
// USAGE:
//   - View: wiki.php?page=Home
//   - Edit: wiki.php?page=Home&action=edit
//   - Login: wiki.php?action=login
//   - Logout: wiki.php?action=logout
//

// =============================================================================
// CONFIGURATION
// =============================================================================

define('DB_HOST', 'localhost');
define('DB_USER', 'notlfs_user');
define('DB_PASS', 'your_password_here');
define('DB_NAME', 'notlfs_wiki');

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
    
    // Wiki pages table
    $db->query("
        CREATE TABLE IF NOT EXISTS wiki_pages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            slug VARCHAR(255) NOT NULL UNIQUE,
            content TEXT NOT NULL,
            created_by INT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
        )
    ");
    
    // Check if admin user exists, if not create one
    $result = $db->query("SELECT * FROM users WHERE username = 'admin'");
    if ($result->num_rows === 0) {
        // Default admin password: admin123 (CHANGE THIS!)
        $hash = password_hash('admin123', PASSWORD_DEFAULT);
        $db->query("INSERT INTO users (username, password, is_admin) VALUES ('admin', '$hash', TRUE)");
        
        // Create a default home page
        $db->query("INSERT INTO wiki_pages (title, slug, content, created_by) 
                   VALUES ('Home', 'home', '# Welcome to NotLFS Wiki\n\nThis is the default home page. Edit it to add your content!', 1)");
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
    // Headers
    $text = preg_replace('/^# (.*$)/m', '<h1>$1</h1>', $text);
    $text = preg_replace('/^## (.*$)/m', '<h2>$1</h2>', $text);
    $text = preg_replace('/^### (.*$)/m', '<h3>$1</h3>', $text);
    
    // Bold and italic
    $text = preg_replace('/\*\*(.*?)\*\*/', '<strong>$1</strong>', $text);
    $text = preg_replace('/\*(.*?)\*/', '<em>$1</em>', $text);
    
    // Links
    $text = preg_replace('/\[(.*?)\]\((.*?)\)/', '<a href="$2">$1</a>', $text);
    
    // Code blocks
    $text = preg_replace('/```(.*?)\n(.*?)```/s', '<pre><code>$2</code></pre>', $text);
    $text = preg_replace('/`(.*?)`/', '<code>$1</code>', $text);
    
    // Lists
    $text = preg_replace('/^\* (.*$)/m', '<li>$1</li>', $text);
    $text = preg_replace('/^\- (.*$)/m', '<li>$1</li>', $text);
    
    // Paragraphs
    $text = '<p>' . str_replace("\n\n", '</p><p>', $text) . '</p>';
    $text = str_replace("\n", '<br>', $text);
    
    return $text;
}

// =============================================================================
// WIKI FUNCTIONS
// =============================================================================

function get_page($slug) {
    $db = db_connect();
    $stmt = $db->prepare("SELECT * FROM wiki_pages WHERE slug = ?");
    $stmt->bind_param("s", $slug);
    $stmt->execute();
    $result = $stmt->get_result();
    return $result->fetch_assoc();
}

function get_all_pages() {
    $db = db_connect();
    $result = $db->query("SELECT * FROM wiki_pages ORDER BY title");
    return $result->fetch_all(MYSQLI_ASSOC);
}

function save_page($title, $slug, $content, $user_id) {
    $db = db_connect();
    
    $existing = get_page($slug);
    if ($existing) {
        $stmt = $db->prepare("UPDATE wiki_pages SET title = ?, content = ?, updated_at = CURRENT_TIMESTAMP WHERE slug = ?");
        $stmt->bind_param("sss", $title, $content, $slug);
    } else {
        $stmt = $db->prepare("INSERT INTO wiki_pages (title, slug, content, created_by) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("sssi", $title, $slug, $content, $user_id);
    }
    return $stmt->execute();
}

function delete_page($slug) {
    $db = db_connect();
    $stmt = $db->prepare("DELETE FROM wiki_pages WHERE slug = ?");
    $stmt->bind_param("s", $slug);
    return $stmt->execute();
}

// =============================================================================
// ACTION HANDLERS
// =============================================================================

$action = $_GET['action'] ?? '';
$page = $_GET['page'] ?? 'home';

// Handle logout
if ($action === 'logout') {
    session_destroy();
    redirect('wiki.php');
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
        redirect('wiki.php');
    } else {
        $error = "Invalid username or password";
    }
}

// Handle save page
if ($action === 'save' && $_SERVER['REQUEST_METHOD'] === 'POST' && is_logged_in()) {
    $title = trim($_POST['title'] ?? '');
    $slug = slugify($title);
    $content = $_POST['content'] ?? '';
    $user_id = $_SESSION['user_id'];
    
    if (empty($title)) {
        $error = "Title is required";
    } elseif (empty($content)) {
        $error = "Content is required";
    } else {
        save_page($title, $slug, $content, $user_id);
        redirect("wiki.php?page=$slug");
    }
}

// Handle delete page
if ($action === 'delete' && is_logged_in()) {
    $slug = $_GET['page'] ?? '';
    if (is_admin() || get_page($slug)['created_by'] == $_SESSION['user_id']) {
        delete_page($slug);
        redirect('wiki.php');
    }
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
    <title>NotLFS Wiki<?php echo $page !== 'home' ? " - " . sanitize($page) : ''; ?></title>
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
        .edit-link { float: right; margin-top: 10px; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 5px; font-weight: bold; }
        .form-group input, .form-group textarea { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        .form-group textarea { min-height: 300px; }
        .btn { padding: 8px 15px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; }
        .btn:hover { background: #0055aa; }
        .btn-danger { background: #cc0000; }
        .btn-danger:hover { background: #aa0000; }
        .error { color: #cc0000; }
        .success { color: #009900; }
        .pages-list { list-style: none; }
        .pages-list li { margin: 5px 0; }
        .pages-list a { font-size: 1.1em; }
        hr { border: none; border-top: 1px solid #eee; margin: 20px 0; }
        @media (max-width: 768px) { .user-info { float: none; margin-top: 10px; } }
    </style>
</head>
<body>
    <header>
        <h1><a href="wiki.php">NotLFS Wiki</a></h1>
        <nav class="nav">
            <a href="wiki.php">Home</a>
            <a href="wiki.php?action=list">All Pages</a>
            <?php if (is_logged_in()): ?>
                <a href="wiki.php?action=new">New Page</a>
            <?php endif; ?>
            <span class="user-info">
                <?php if (is_logged_in()): ?>
                    <?php $user = get_user(); echo "Hello, " . sanitize($user['username']); ?> |
                    <a href="wiki.php?action=logout">Logout</a>
                <?php else: ?>
                    <a href="wiki.php?action=login">Login</a>
                    <a href="wiki.php?action=register">Register</a>
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
        
        if ($action === 'list'):
            // List all pages
            $pages = get_all_pages();
            echo "<h2>All Wiki Pages</h2>\n";
            echo "<ul class='pages-list'>\n";
            foreach ($pages as $p) {
                echo "<li><a href='wiki.php?page=" . sanitize($p['slug']) . "'>" . sanitize($p['title']) . "</a></li>\n";
            }
            echo "</ul>\n";
            
        elseif ($action === 'new' || $action === 'edit'):
            // Edit/new page form
            $editing = null;
            if ($action === 'edit' && $page) {
                $editing = get_page($page);
            }
            
            if (!is_logged_in()) {
                echo "<p class='error'>You must be logged in to edit pages.</p>\n";
            } else {
                echo "<h2>" . ($action === 'edit' ? 'Edit' : 'New') . " Page</h2>\n";
                echo "<form method='post' action='wiki.php?action=save'>\n";
                echo "    <input type='hidden' name='page' value='" . sanitize($page) . "'>\n";
                echo "    <div class='form-group'>\n";
                echo "        <label for='title'>Title:</label>\n";
                echo "        <input type='text' id='title' name='title' value='" . sanitize($editing['title'] ?? '') . "' required>\n";
                echo "    </div>\n";
                echo "    <div class='form-group'>\n";
                echo "        <label for='content'>Content (Markdown supported):</label>\n";
                echo "        <textarea id='content' name='content' required>" . sanitize($editing['content'] ?? '') . "</textarea>\n";
                echo "    </div>\n";
                echo "    <button type='submit' class='btn'>Save Page</button>\n";
                if ($action === 'edit' && $editing) {
                    echo "    <a href='wiki.php?page=" . sanitize($editing['slug']) . "&action=delete' class='btn btn-danger' onclick='return confirm(\"Are you sure?\")'>Delete</a>\n";
                }
                echo "</form>\n";
            }
            
        elseif ($action === 'login'):
            // Login form
            echo "<h2>Login</h2>\n";
            echo "<form method='post' action='wiki.php?action=login'>\n";
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
            echo "<p>Don't have an account? <a href='wiki.php?action=register'>Register</a></p>\n";
            
        elseif ($action === 'register'):
            // Registration form
            if ($_SERVER['REQUEST_METHOD'] === 'POST') {
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
                        redirect("wiki.php?action=login&success=Registration successful. Please login.");
                    }
                }
            }
            
            echo "<h2>Register</h2>\n";
            echo "<form method='post' action='wiki.php?action=register'>\n";
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
            echo "<p>Already have an account? <a href='wiki.php?action=login'>Login</a></p>\n";
            
        else:
            // View a page
            $page_data = get_page($page);
            if (!$page_data) {
                // Page doesn't exist, offer to create it
                echo "<p class='error'>Page not found.</p>\n";
                echo "<p><a href='wiki.php?action=new'>Create this page</a></p>\n";
            } else {
                echo "<div class='edit-link'>\n";
                if (is_logged_in()) {
                    echo "    <a href='wiki.php?page=" . sanitize($page_data['slug']) . "&action=edit' class='btn'>Edit</a>\n";
                } else {
                    echo "    <a href='wiki.php?action=login' class='btn'>Login to Edit</a>\n";
                }
                echo "</div>\n";
                echo "<h2>" . sanitize($page_data['title']) . "</h2>\n";
                echo "<div class='wiki-content'>\n";
                echo markdown($page_data['content']);
                echo "</div>\n";
            }
        
        ?>
    </main>
    
    <footer>
        <hr>
        <p>NotLFS Wiki - A simple wiki for the NotLFS project</p>
    </footer>
</body>
</html>