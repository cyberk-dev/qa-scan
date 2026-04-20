// QA Test App - Hono server with auth, CRUD, and UI features
import { Hono } from 'hono';
import { getCookie, setCookie, deleteCookie } from 'hono/cookie';
import { db } from './data';
import { layout } from './views/layout';
import { loginPage } from './views/login';
import { dashboardPage } from './views/dashboard';
import { usersListPage, userFormPage } from './views/users';
import { profilePage } from './views/profile';

const app = new Hono();

// Auth middleware
const requireAuth = async (c: any, next: () => Promise<void>) => {
  const token = getCookie(c, 'session');
  if (!token) return c.redirect('/login');
  const session = db.getSession(token);
  if (!session) {
    deleteCookie(c, 'session');
    return c.redirect('/login');
  }
  c.set('session', session);
  c.set('token', token);
  await next();
};

// Public routes
app.get('/', (c) => c.redirect('/login'));

app.get('/login', (c) => {
  const token = getCookie(c, 'session');
  if (token && db.getSession(token)) return c.redirect('/dashboard');
  return c.html(loginPage());
});

app.post('/login', async (c) => {
  const body = await c.req.parseBody();
  const email = body.email as string;
  const password = body.password as string;
  const session = db.authenticate(email, password);
  if (!session) return c.html(loginPage('Invalid email or password'));

  // Get the token that was just created
  const token = crypto.randomUUID();
  setCookie(c, 'session', token, { path: '/', httpOnly: true, maxAge: 86400 });

  // Store session with our token
  (db as any).sessions = (db as any).sessions || new Map();
  (db as any).sessions.set(token, session);

  return c.redirect('/dashboard');
});

app.post('/logout', (c) => {
  const token = getCookie(c, 'session');
  if (token) db.deleteSession(token);
  deleteCookie(c, 'session');
  return c.redirect('/login');
});

// Protected routes
app.get('/dashboard', requireAuth, (c) => {
  const session = c.get('session');
  const stats = db.getStats();
  return c.html(layout('Dashboard', dashboardPage(stats), session));
});

app.get('/users', requireAuth, (c) => {
  const session = c.get('session');
  const name = c.req.query('name');
  const role = c.req.query('role');
  const users = db.listUsers({ name, role });
  return c.html(layout('Users', usersListPage(users, { name, role }), session));
});

app.get('/users/new', requireAuth, (c) => {
  const session = c.get('session');
  return c.html(layout('New User', userFormPage(), session));
});

app.post('/users', requireAuth, async (c) => {
  const body = await c.req.parseBody();
  db.createUser({
    name: body.name as string,
    email: body.email as string,
    role: body.role as 'admin' | 'user' | 'viewer',
  });
  return c.redirect('/users?toast=User created successfully');
});

app.get('/users/:id/edit', requireAuth, (c) => {
  const session = c.get('session');
  const user = db.getUser(c.req.param('id'));
  if (!user) return c.redirect('/users?toast=User not found&type=error');
  return c.html(layout('Edit User', userFormPage(user), session));
});

app.post('/users/:id', requireAuth, async (c) => {
  const body = await c.req.parseBody();
  db.updateUser(c.req.param('id'), {
    name: body.name as string,
    email: body.email as string,
    role: body.role as 'admin' | 'user' | 'viewer',
  });
  return c.redirect('/users?toast=User updated successfully');
});

app.post('/users/:id/delete', requireAuth, (c) => {
  db.deleteUser(c.req.param('id'));
  return c.redirect('/users?toast=User deleted successfully');
});

app.get('/profile', requireAuth, (c) => {
  const session = c.get('session');
  const message = c.req.query('saved') ? 'Settings saved successfully' : undefined;
  return c.html(layout('Profile', profilePage(message), session));
});

app.post('/profile', requireAuth, async (c) => {
  return c.redirect('/profile?saved=1');
});

// Health check for E2E tests
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }));

export default {
  port: 3002,
  fetch: app.fetch,
};

console.log('🚀 QA Test App running on http://localhost:3002');
