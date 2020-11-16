const _storage = {};

const storage = {
    get(key) {
        return _storage[key];
    },
    set(key, value) {
        _storage[key] = value;
    },
    clear(key) {
        delete _storage[key];
    }
};

module.exports = storage;
