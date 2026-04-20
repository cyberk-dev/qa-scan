// In-memory mock data store for test-app

export interface User {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'user' | 'viewer';
  createdAt: string;
}

export interface Session {
  userId: string;
  name: string;
}

// Mock users
const users: Map<string, User> = new Map([
  ['1', { id: '1', name: 'Alice Admin', email: 'alice@example.com', role: 'admin', createdAt: '2026-01-15' }],
  ['2', { id: '2', name: 'Bob User', email: 'bob@example.com', role: 'user', createdAt: '2026-02-20' }],
  ['3', { id: '3', name: 'Carol Viewer', email: 'carol@example.com', role: 'viewer', createdAt: '2026-03-10' }],
]);

// Mock credentials
const credentials: Record<string, string> = {
  'alice@example.com': 'admin123',
  'bob@example.com': 'user123',
  'carol@example.com': 'viewer123',
};

// Sessions (token -> session)
const sessions: Map<string, Session> = new Map();

let nextId = 4;

export const db = {
  // Auth
  authenticate(email: string, password: string): Session | null {
    if (credentials[email] === password) {
      const user = [...users.values()].find(u => u.email === email);
      if (user) {
        const token = crypto.randomUUID();
        const session = { userId: user.id, name: user.name };
        sessions.set(token, session);
        return session;
      }
    }
    return null;
  },

  getSession(token: string): Session | null {
    return sessions.get(token) || null;
  },

  deleteSession(token: string): void {
    sessions.delete(token);
  },

  // Users CRUD
  listUsers(filter?: { name?: string; role?: string }): User[] {
    let result = [...users.values()];
    if (filter?.name) {
      const q = filter.name.toLowerCase();
      result = result.filter(u => u.name.toLowerCase().includes(q));
    }
    if (filter?.role) {
      result = result.filter(u => u.role === filter.role);
    }
    return result;
  },

  getUser(id: string): User | null {
    return users.get(id) || null;
  },

  createUser(data: Omit<User, 'id' | 'createdAt'>): User {
    const id = String(nextId++);
    const user: User = { ...data, id, createdAt: new Date().toISOString().split('T')[0] };
    users.set(id, user);
    return user;
  },

  updateUser(id: string, data: Partial<Omit<User, 'id' | 'createdAt'>>): User | null {
    const user = users.get(id);
    if (!user) return null;
    Object.assign(user, data);
    return user;
  },

  deleteUser(id: string): boolean {
    return users.delete(id);
  },

  // Stats
  getStats() {
    const all = [...users.values()];
    return {
      total: all.length,
      admins: all.filter(u => u.role === 'admin').length,
      users: all.filter(u => u.role === 'user').length,
      viewers: all.filter(u => u.role === 'viewer').length,
    };
  },
};
