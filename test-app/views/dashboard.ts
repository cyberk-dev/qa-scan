// Dashboard page view

export const dashboardPage = (stats: { total: number; admins: number; users: number; viewers: number }) => `
<h1 class="text-3xl font-bold mb-8" data-testid="dashboard-title">Dashboard</h1>
<div class="grid grid-cols-1 md:grid-cols-4 gap-6">
  <div class="bg-white rounded-lg shadow p-6" data-testid="stat-total">
    <div class="text-gray-500 text-sm">Total Users</div>
    <div class="text-3xl font-bold text-gray-900">${stats.total}</div>
  </div>
  <div class="bg-white rounded-lg shadow p-6" data-testid="stat-admins">
    <div class="text-gray-500 text-sm">Admins</div>
    <div class="text-3xl font-bold text-red-600">${stats.admins}</div>
  </div>
  <div class="bg-white rounded-lg shadow p-6" data-testid="stat-users">
    <div class="text-gray-500 text-sm">Users</div>
    <div class="text-3xl font-bold text-blue-600">${stats.users}</div>
  </div>
  <div class="bg-white rounded-lg shadow p-6" data-testid="stat-viewers">
    <div class="text-gray-500 text-sm">Viewers</div>
    <div class="text-3xl font-bold text-green-600">${stats.viewers}</div>
  </div>
</div>
<div class="mt-8 bg-white rounded-lg shadow p-6">
  <h2 class="text-xl font-semibold mb-4">Quick Actions</h2>
  <div class="flex space-x-4">
    <a href="/users" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded" data-testid="goto-users">Manage Users</a>
    <a href="/users/new" class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded" data-testid="add-user-btn">Add User</a>
  </div>
</div>
`;
