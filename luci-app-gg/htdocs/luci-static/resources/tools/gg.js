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

const callGGGetPaths = rpc.declare({
    object: 'luci.gg',
    method: 'get_paths',
    expect: { '': {} }
});

const callGGVersion = rpc.declare({
    object: 'luci.gg',
    method: 'version',
    expect: { '': {} }
});

const callGGUpdateSubscription = rpc.declare({
    object: 'luci.gg',
    method: 'update_subscription',
    params: ['section_id'],
    expect: { '': {} }
});

const callGGSubscriptionStatus = rpc.declare({
    object: 'luci.gg',
    method: 'subscription_status',
    expect: { '': {} }
});

const callGGDebug = rpc.declare({
    object: 'luci.gg',
    method: 'debug',
    expect: { '': {} }
});

const callGGCoreInfo = rpc.declare({
    object: 'luci.gg',
    method: 'core_info',
    expect: { '': {} }
});

const callGGCheckCoreUpdate = rpc.declare({
    object: 'luci.gg',
    method: 'check_core_update',
    expect: { '': {} }
});

const callGGUpdateCore = rpc.declare({
    object: 'luci.gg',
    method: 'update_core',
    params: ['channel'],
    expect: { '': {} }
});

const callGGRollbackCore = rpc.declare({
    object: 'luci.gg',
    method: 'rollback_core',
    expect: { '': {} }
});

const callGGCoreUpdateStatus = rpc.declare({
    object: 'luci.gg',
    method: 'core_update_status',
    expect: { '': {} }
});

return baseclass.extend({
    getPaths: async function () {
        return callGGGetPaths();
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
        return callGGVersion();
    },

    updateSubscription: function (section_id) {
        return callGGUpdateSubscription(section_id);
    },

    subscriptionStatus: function () {
        return callGGSubscriptionStatus();
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
        return callGGDebug();
    },

    coreInfo: function () {
        return callGGCoreInfo();
    },

    checkCoreUpdate: function () {
        return callGGCheckCoreUpdate();
    },

    updateCore: function (channel) {
        return callGGUpdateCore(channel);
    },

    rollbackCore: function () {
        return callGGRollbackCore();
    },

    coreUpdateStatus: function () {
        return callGGCoreUpdateStatus();
    },
})
