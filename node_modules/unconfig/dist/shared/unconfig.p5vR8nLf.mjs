function toArray(array) {
  array = array ?? [];
  return Array.isArray(array) ? array : [array];
}

export { toArray as t };
