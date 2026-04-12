import axios from 'axios';

export const api = axios.create({
  baseURL: 'https://your-api-base-url.com/api',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});
