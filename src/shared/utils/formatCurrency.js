export const formatCurrency = (value) => {
  return `UGX ${Number(value || 0).toLocaleString()}`;
};
