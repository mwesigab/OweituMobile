const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const validators = {
  email: () => (value) => {
    if (!value) {
      return null;
    }

    return EMAIL_REGEX.test(String(value).trim())
      ? null
      : 'Enter a valid email address.';
  },
  minLength: (length, label = 'This field') => (value) => {
    return String(value || '').trim().length >= length
      ? null
      : `${label} must be at least ${length} characters.`;
  },
  required: (label = 'This field') => (value) => {
    return String(value || '').trim() ? null : `${label} is required.`;
  },
};

export const validateField = (value, rules = []) => {
  for (const rule of rules) {
    const error = rule(value);

    if (error) {
      return error;
    }
  }

  return '';
};

export const validateForm = (values, schema) => {
  return Object.keys(schema).reduce((errors, key) => {
    const error = validateField(values[key], schema[key]);

    if (error) {
      errors[key] = error;
    }

    return errors;
  }, {});
};
