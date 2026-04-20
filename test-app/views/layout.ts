// HTML layout wrapper with Tailwind CDN

export const layout = (title: string, content: string, session?: { name: string } | null) => `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} - QA Test App</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 min-h-screen">
  ${session ? nav(session.name) : ''}
  <main class="container mx-auto px-4 py-8">
    ${content}
  </main>
  <div id="toast-container" class="fixed bottom-4 right-4 space-y-2"></div>
  <script>
    function showToast(message, type = 'success') {
      const container = document.getElementById('toast-container');
      const toast = document.createElement('div');
      toast.className = 'px-4 py-2 rounded shadow-lg text-white ' +
        (type === 'success' ? 'bg-green-500' : type === 'error' ? 'bg-red-500' : 'bg-blue-500');
      toast.textContent = message;
      container.appendChild(toast);
      setTimeout(() => toast.remove(), 3000);
    }
    // Show toast from URL param
    const params = new URLSearchParams(window.location.search);
    if (params.get('toast')) showToast(params.get('toast'), params.get('type') || 'success');
  </script>
</body>
</html>
`;

const nav = (userName: string) => `
<nav class="bg-white shadow">
  <div class="container mx-auto px-4">
    <div class="flex justify-between h-16">
      <div class="flex space-x-8">
        <a href="/dashboard" class="flex items-center px-3 text-gray-700 hover:text-blue-600" data-testid="nav-dashboard">Dashboard</a>
        <a href="/users" class="flex items-center px-3 text-gray-700 hover:text-blue-600" data-testid="nav-users">Users</a>
        <a href="/profile" class="flex items-center px-3 text-gray-700 hover:text-blue-600" data-testid="nav-profile">Profile</a>
      </div>
      <div class="flex items-center space-x-4">
        <span class="text-gray-600" data-testid="user-name">${userName}</span>
        <form action="/logout" method="POST" class="inline">
          <button type="submit" class="text-red-600 hover:text-red-800" data-testid="logout-btn">Logout</button>
        </form>
      </div>
    </div>
  </div>
</nav>
`;
