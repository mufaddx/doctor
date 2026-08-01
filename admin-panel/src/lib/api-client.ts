import axios, {
  AxiosError,
  AxiosInstance,
  InternalAxiosRequestConfig,
} from 'axios';

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000/api/v1';

const ACCESS_TOKEN_KEY = 'toc_admin_access_token';
const REFRESH_TOKEN_KEY = 'toc_admin_refresh_token';

export interface ApiEnvelope<T> {
  success: boolean;
  statusCode: number;
  data: T;
  timestamp: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  meta: { total: number; page: number; limit: number; totalPages: number };
}

export class ApiError extends Error {
  constructor(
    message: string,
    public statusCode?: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

/** Tokens live in localStorage; the panel is an SPA behind a login wall. */
export const tokenStore = {
  getAccess: () =>
    typeof window === 'undefined' ? null : localStorage.getItem(ACCESS_TOKEN_KEY),
  getRefresh: () =>
    typeof window === 'undefined'
      ? null
      : localStorage.getItem(REFRESH_TOKEN_KEY),
  set: (accessToken: string, refreshToken: string) => {
    localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  },
  clear: () => {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
  },
};

const client: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30_000,
  headers: { 'Content-Type': 'application/json' },
});

client.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = tokenStore.getAccess();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

/**
 * Concurrent 401s all wait on a single refresh call, then replay. Without the
 * shared promise, a dashboard that fires eight requests at once would trigger
 * eight refreshes and invalidate its own tokens through rotation.
 */
let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  if (refreshPromise) return refreshPromise;

  refreshPromise = (async () => {
    try {
      const refreshToken = tokenStore.getRefresh();
      if (!refreshToken) return null;

      const { data } = await axios.post<ApiEnvelope<{
        accessToken: string;
        refreshToken: string;
      }>>(`${API_BASE_URL}/auth/refresh`, { refreshToken });

      tokenStore.set(data.data.accessToken, data.data.refreshToken);
      return data.data.accessToken;
    } catch {
      tokenStore.clear();
      return null;
    } finally {
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}

client.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<{ message?: string | string[] }>) => {
    const original = error.config as InternalAxiosRequestConfig & {
      _retried?: boolean;
    };

    if (error.response?.status === 401 && original && !original._retried) {
      original._retried = true;

      const token = await refreshAccessToken();

      if (token) {
        original.headers.Authorization = `Bearer ${token}`;
        return client(original);
      }

      if (typeof window !== 'undefined') window.location.href = '/login';
    }

    const payload = error.response?.data?.message;
    const message = Array.isArray(payload)
      ? payload[0]
      : (payload ?? 'Something went wrong. Please try again.');

    return Promise.reject(new ApiError(message, error.response?.status));
  },
);

/** Unwraps the API envelope so callers work with plain data. */
async function unwrap<T>(promise: Promise<{ data: ApiEnvelope<T> }>): Promise<T> {
  const response = await promise;
  return response.data.data;
}

export const api = {
  get: <T>(url: string, params?: Record<string, unknown>) =>
    unwrap<T>(client.get<ApiEnvelope<T>>(url, { params })),

  post: <T>(url: string, body?: unknown) =>
    unwrap<T>(client.post<ApiEnvelope<T>>(url, body)),

  patch: <T>(url: string, body?: unknown) =>
    unwrap<T>(client.patch<ApiEnvelope<T>>(url, body)),

  put: <T>(url: string, body?: unknown) =>
    unwrap<T>(client.put<ApiEnvelope<T>>(url, body)),

  delete: <T>(url: string) => unwrap<T>(client.delete<ApiEnvelope<T>>(url)),
};

export default client;
