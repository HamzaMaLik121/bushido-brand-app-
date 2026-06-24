const API_BASE = '/api';

const api = {
    async get(endpoint, token = null) {
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;
        const res = await fetch(`${API_BASE}${endpoint}`, { headers });
        return await res.json();
    },

    async post(endpoint, data, token = null) {
        const headers = { 'Content-Type': 'application/json' };
        if (token) headers['Authorization'] = `Bearer ${token}`;
        const res = await fetch(`${API_BASE}${endpoint}`, {
            method: 'POST',
            headers,
            body: JSON.stringify(data)
        });
        return await res.json();
    },

    async delete(endpoint, token = null) {
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;
        const res = await fetch(`${API_BASE}${endpoint}`, {
            method: 'DELETE',
            headers
        });
        return await res.json();
    }
};
