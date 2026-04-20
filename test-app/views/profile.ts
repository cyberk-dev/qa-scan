// Profile settings view

export const profilePage = (message?: string) => `
<h1 class="text-3xl font-bold mb-6" data-testid="profile-title">Profile Settings</h1>

${message ? `<div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4" data-testid="profile-message">${message}</div>` : ''}

<form method="POST" action="/profile" class="bg-white rounded-lg shadow p-6 max-w-lg" data-testid="profile-form">
  <div class="mb-4">
    <label class="block text-gray-700 text-sm font-bold mb-2">Display Name</label>
    <input type="text" name="displayName" placeholder="Your display name"
      class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700" data-testid="display-name-input">
  </div>
  <div class="mb-4">
    <label class="block text-gray-700 text-sm font-bold mb-2">Email Notifications</label>
    <label class="flex items-center">
      <input type="checkbox" name="notifications" value="1" class="mr-2" data-testid="notifications-checkbox">
      <span>Receive email notifications</span>
    </label>
  </div>
  <div class="mb-6">
    <label class="block text-gray-700 text-sm font-bold mb-2">Theme</label>
    <select name="theme" class="shadow border rounded w-full py-2 px-3 text-gray-700" data-testid="theme-select">
      <option value="light">Light</option>
      <option value="dark">Dark</option>
      <option value="system">System</option>
    </select>
  </div>
  <button type="submit" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded" data-testid="save-profile-btn">
    Save Settings
  </button>
</form>
`;
