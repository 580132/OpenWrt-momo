'use strict';
'require baseclass';
'require uci';
'require fs';
'require rpc';
'require request';

const callRCList = rpc.declare({
    object: 'rc',
    method: 'list',
    params: ['name'],
    expect: { '': {} }
});

const callRCInit = rpc.declare({
    object: 'rc',
    method: 'init',
    params: ['name', 'action'],
    expect: { '': {} }
});

const callFileWrite = rpc.declare({
    object: 'file',
    method: 'write',
    params: ['path', 'data', 'append', 'mode']
});

const callMomoGetPaths = rpc.declare({
    object: 'luci.gg',
    method: 'get_paths',
    expect: { '': {} }
});

const callMomoVersion = rpc.declare({
    object: 'luci.gg',
    method: 'version',
    expect: { '': {} }
});

const callMomoUpdateSubscription = rpc.declare({
    object: 'luci.gg',
    method: 'update_subscription',
    params: ['section_id'],
    expect: { '': {} }
});

const callMomoDebug = rpc.declare({
    object: 'luci.gg',
    method: 'debug',
    expect: { '': {} }
});

const callMomoCoreInfo = rpc.declare({
    object: 'luci.gg',
    method: 'core_info',
    expect: { '': {} }
});

const callMomoCheckCoreUpdate = rpc.declare({
    object: 'luci.gg',
    method: 'check_core_update',
    expect: { '': {} }
});

const callMomoUpdateCore = rpc.declare({
    object: 'luci.gg',
    method: 'update_core',
    params: ['channel'],
    expect: { '': {} }
});

const callMomoRollbackCore = rpc.declare({
    object: 'luci.gg',
    method: 'rollback_core',
    expect: { '': {} }
});

const callMomoCoreUpdateStatus = rpc.declare({
    object: 'luci.gg',
    method: 'core_update_status',
    expect: { '': {} }
});

return baseclass.extend({
    getPaths: async function () {
        return callMomoGetPaths();
    },

    status: async function () {
        return (await callRCList('gg'))?.gg?.running;
    },

    reload: function () {
        return callRCInit('gg', 'reload');
    },

    restart: function () {
        return callRCInit('gg', 'restart');
    },

    writefile: function (path, data, mode) {
        data = (data != null) ? String(data) : '';
        mode = (mode != null) ? mode : 0o644;

        const encoder = new TextEncoder();
        const decoder = new TextDecoder();
        const chunkSize = 8 * 1024;

        const bytes = encoder.encode(data);

        if (bytes.length <= chunkSize) {
            return callFileWrite(path, data, false, mode);
        }

        let promise = Promise.resolve();
        for(let offset = 0; offset < bytes.length; offset += chunkSize) {
            const chunkStart = offset;
            const chunkEnd = Math.min(offset + chunkSize, bytes.length);
            const isLastChunk = chunkEnd === bytes.length;
            const chunkBytes = bytes.slice(chunkStart, chunkEnd);
            const chunk = decoder.decode(chunkBytes, { stream: !isLastChunk });
            const append = offset > 0;
            promise = promise.then(() => callFileWrite(path, chunk, append, mode));
        }

        return promise;
    },

    version: function () {
        return callMomoVersion();
    },

    updateSubscription: function (section_id) {
        return callMomoUpdateSubscription(section_id);
    },

    

    listProfiles: async function () {
        const paths = await this.getPaths();
        return L.resolveDefault(fs.list(paths.profiles_dir), []);
    },

    getAppLog: async function () {
        const paths = await this.getPaths();
        return L.resolveDefault(fs.read_direct(paths.app_log_path));
    },

    getCoreLog: async function () {
        const paths = await this.getPaths();
        return L.resolveDefault(fs.read_direct(paths.core_log_path));
    },

    clearAppLog: async function () {
        const paths = await this.getPaths();
        return this.writefile(paths.app_log_path);
    },

    clearCoreLog: async function () {
        const paths = await this.getPaths();
        return this.writefile(paths.core_log_path);
    },

    debug: function () {
        return callMomoDebug();
    },

    coreInfo: function () {
        return callMomoCoreInfo();
    },

    checkCoreUpdate: function () {
        return callMomoCheckCoreUpdate();
    },

    updateCore: function (channel) {
        return callMomoUpdateCore(channel);
    },

    rollbackCore: function () {
        return callMomoRollbackCore();
    },

    coreUpdateStatus: function () {
        return callMomoCoreUpdateStatus();
    },
})
