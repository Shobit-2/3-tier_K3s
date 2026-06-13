import axios from 'axios';

const API = axios.create({
  baseURL: window._env_?.REACT_APP_API_URL || process.env.REACT_APP_API_URL || '/api',
});

export const getUsers = () => API.get('/users');
export const getUser = (id) => API.get(`/users/${id}`);
export const createUser = (data) => API.post('/users', data);
export const updateUser = (id, data) => API.put(`/users/${id}`, data);
export const deleteUser = (id) => API.delete(`/users/${id}`);
