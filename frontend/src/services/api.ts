const BASE_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:3000';

export class ApiError extends Error {
  status: number;
  endpoint: string;
  data: unknown;

  constructor(message: string, status: number, endpoint: string, data?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.endpoint = endpoint;
    this.data = data;
  }
}

interface RequestOptions extends RequestInit {
  data?: unknown;
}

export class ApiClient {
  public baseURL: string;

  constructor(baseURL: string = BASE_URL) {
    this.baseURL = baseURL;
  }

  private getAuthHeader(): Record<string, string> {
    const token = sessionStorage.getItem('chaindock_token') || localStorage.getItem('chaindock_token');
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  async request<T>(endpoint: string, options: RequestOptions = {}): Promise<{ data: T; status: number }> {
    const cleanBase = this.baseURL.replace(/\/+$/, '');
    const cleanEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
    const url = `${cleanBase}${cleanEndpoint}`;

    const { data: requestData, headers: _customHeaders, ...fetchOptions } = options;
    const isFormData = requestData instanceof FormData;
    const hasJsonBody = requestData !== undefined && !isFormData;

    const headers: Record<string, string> = {
      ...this.getAuthHeader(),
      ...(options.headers as Record<string, string>),
    };

    if (hasJsonBody) {
      headers['Content-Type'] = 'application/json';
    }

    const config: RequestInit = {
      ...fetchOptions,
      headers,
    };

    if (hasJsonBody) {
      config.body = JSON.stringify(requestData);
    } else if (isFormData) {
      // Let fetch calculate multipart/form-data boundary for Axum Multipart extractor
      delete headers['Content-Type'];
      config.body = requestData as FormData;
    }

    let response: Response;
    try {
      response = await fetch(url, config);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Network request failed';
      throw new ApiError(`Unable to connect to backend service (${msg})`, 0, endpoint);
    }

    const contentType = response.headers.get('content-type');
    let data: T;
    if (contentType && contentType.includes('application/json')) {
      try {
        data = await response.json();
      } catch {
        data = null as unknown as T;
      }
    } else {
      data = (await response.text()) as unknown as T;
    }

    if (!response.ok) {
      if (response.status === 401) {
        sessionStorage.removeItem('chaindock_token');
        localStorage.removeItem('chaindock_token');
        if (typeof window !== 'undefined') {
          window.dispatchEvent(new CustomEvent('chaindock:unauthorized'));
        }
      }

      const errorObj = typeof data === 'object' && data !== null ? (data as Record<string, unknown>) : null;
      const textError = typeof data === 'string' && data.trim().length > 0 ? data.trim() : null;
      const errorMsg =
        errorObj?.error
          ? String(errorObj.error)
          : errorObj?.message
          ? String(errorObj.message)
          : errorObj?.detail
          ? String(errorObj.detail)
          : textError
          ? textError
          : `HTTP ${response.status}: ${response.statusText || 'Request failed'}`;

      throw new ApiError(errorMsg, response.status, endpoint, data);
    }

    return { data, status: response.status };
  }

  get<T>(endpoint: string, headers?: Record<string, string>) {
    return this.request<T>(endpoint, { method: 'GET', headers });
  }

  post<T>(endpoint: string, data?: unknown, headers?: Record<string, string>) {
    return this.request<T>(endpoint, { method: 'POST', data, headers });
  }

  put<T>(endpoint: string, data?: unknown, headers?: Record<string, string>) {
    return this.request<T>(endpoint, { method: 'PUT', data, headers });
  }

  patch<T>(endpoint: string, data?: unknown, headers?: Record<string, string>) {
    return this.request<T>(endpoint, { method: 'PATCH', data, headers });
  }

  delete<T>(endpoint: string, headers?: Record<string, string>) {
    return this.request<T>(endpoint, { method: 'DELETE', headers });
  }
}

export const api = new ApiClient();
