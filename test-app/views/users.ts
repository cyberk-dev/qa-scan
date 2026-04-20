// Users CRUD views
import type { User } from '../data';

export const usersListPage = (users: User[], filter: { name?: string; role?: string }) => `
<div class="flex justify-between items-center mb-6">
  <h1 class="text-3xl font-bold" data-testid="users-title">Users</h1>
  <a href="/users/new" class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded" data-testid="create-user-btn">+ New User</a>
</div>

<form method="GET" class="bg-white p-4 rounded-lg shadow mb-6 flex gap-4" data-testid="search-form">
  <input type="text" name="name" placeholder="Search by name..." value="${filter.name || ''}"
    class="flex-1 border rounded px-3 py-2" data-testid="search-input">
  <select name="role" class="border rounded px-3 py-2" data-testid="role-filter">
    <option value="">All roles</option>
    <option value="admin" ${filter.role === 'admin' ? 'selected' : ''}>Admin</option>
    <option value="user" ${filter.role === 'user' ? 'selected' : ''}>User</option>
    <option value="viewer" ${filter.role === 'viewer' ? 'selected' : ''}>Viewer</option>
  </select>
  <button type="submit" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded" data-testid="search-btn">Search</button>
  <a href="/users" class="bg-gray-300 hover:bg-gray-400 text-gray-800 font-bold py-2 px-4 rounded" data-testid="clear-filter">Clear</a>
</form>

<div class="bg-white rounded-lg shadow overflow-hidden">
  <table class="min-w-full" data-testid="users-table">
    <thead class="bg-gray-50">
      <tr>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created</th>
        <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
      </tr>
    </thead>
    <tbody class="divide-y divide-gray-200">
      ${users.map(u => `
      <tr data-testid="user-row-${u.id}">
        <td class="px-6 py-4">${u.name}</td>
        <td class="px-6 py-4 text-gray-600">${u.email}</td>
        <td class="px-6 py-4"><span class="px-2 py-1 text-xs rounded ${roleColor(u.role)}">${u.role}</span></td>
        <td class="px-6 py-4 text-gray-500">${u.createdAt}</td>
        <td class="px-6 py-4 text-right space-x-2">
          <a href="/users/${u.id}/edit" class="text-blue-600 hover:underline" data-testid="edit-${u.id}">Edit</a>
          <button onclick="confirmDelete('${u.id}', '${u.name}')" class="text-red-600 hover:underline" data-testid="delete-${u.id}">Delete</button>
        </td>
      </tr>
      `).join('')}
      ${users.length === 0 ? '<tr><td colspan="5" class="px-6 py-8 text-center text-gray-500" data-testid="no-users">No users found</td></tr>' : ''}
    </tbody>
  </table>
</div>

<dialog id="delete-modal" class="rounded-lg shadow-xl p-0" data-testid="delete-modal">
  <form method="POST" id="delete-form" class="p-6">
    <h3 class="text-lg font-bold mb-4">Confirm Delete</h3>
    <p class="mb-4">Are you sure you want to delete <strong id="delete-name"></strong>?</p>
    <div class="flex justify-end space-x-2">
      <button type="button" onclick="document.getElementById('delete-modal').close()" class="px-4 py-2 bg-gray-200 rounded" data-testid="cancel-delete">Cancel</button>
      <button type="submit" class="px-4 py-2 bg-red-500 text-white rounded" data-testid="confirm-delete">Delete</button>
    </div>
  </form>
</dialog>

<script>
function confirmDelete(id, name) {
  document.getElementById('delete-form').action = '/users/' + id + '/delete';
  document.getElementById('delete-name').textContent = name;
  document.getElementById('delete-modal').showModal();
}
</script>
`;

const roleColor = (role: string) => {
  switch (role) {
    case 'admin': return 'bg-red-100 text-red-800';
    case 'user': return 'bg-blue-100 text-blue-800';
    default: return 'bg-green-100 text-green-800';
  }
};

export const userFormPage = (user?: User) => `
<h1 class="text-3xl font-bold mb-6" data-testid="form-title">${user ? 'Edit User' : 'New User'}</h1>
<form method="POST" action="${user ? `/users/${user.id}` : '/users'}" class="bg-white rounded-lg shadow p-6 max-w-lg" data-testid="user-form">
  <div class="mb-4">
    <label class="block text-gray-700 text-sm font-bold mb-2">Name</label>
    <input type="text" name="name" required value="${user?.name || ''}"
      class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700" data-testid="name-input">
  </div>
  <div class="mb-4">
    <label class="block text-gray-700 text-sm font-bold mb-2">Email</label>
    <input type="email" name="email" required value="${user?.email || ''}"
      class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700" data-testid="email-input">
  </div>
  <div class="mb-6">
    <label class="block text-gray-700 text-sm font-bold mb-2">Role</label>
    <select name="role" required class="shadow border rounded w-full py-2 px-3 text-gray-700" data-testid="role-select">
      <option value="admin" ${user?.role === 'admin' ? 'selected' : ''}>Admin</option>
      <option value="user" ${user?.role === 'user' ? 'selected' : ''}>User</option>
      <option value="viewer" ${user?.role === 'viewer' ? 'selected' : ''}>Viewer</option>
    </select>
  </div>
  <div class="flex justify-end space-x-2">
    <a href="/users" class="px-4 py-2 bg-gray-200 rounded" data-testid="cancel-btn">Cancel</a>
    <button type="submit" class="px-4 py-2 bg-blue-500 text-white rounded" data-testid="save-btn">${user ? 'Update' : 'Create'}</button>
  </div>
</form>
`;
