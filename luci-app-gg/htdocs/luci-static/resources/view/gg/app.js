'use strict';
'require form';
'require view';
'require uci';
'require poll';
'require ui';
'require tools.gg as gg';

function renderStatus(running) {
    return updateStatus(E('input', { id: 'core_status', style: 'border: unset; font-style: italic; font-weight: bold;', readonly: '' }), running);
}

function updateStatus(element, running) {
    if (element) {
        element.style.color = running ? 'green' : 'red';
        element.value = running ? _('Running') : _('Not Running');
    }
    return element;
}

function renderCoreVersion(version) {
    return E('input', { id: 'core_version', readonly: '', value: version ?? '' });
}

function updateCoreVersion(version) {
    const element = document.getElementById('core_version');
    if (element) {
        element.value = version ?? '';
    }
    return element;
}

function setOptionValue(map, section_id, name, value) {
    const option = map.lookupOption(name, section_id)[0];
    if (option) {
        const element = option.getUIElement(section_id);
        if (element) {
            element.setValue(value ?? '');
        }
    }
}

// The status cell renders the fields the backend stores on the subscription
// section, and the status rpc returns exactly those fields, so the text is
// built in one place and a refresh can just overwrite the cell content.
function subscriptionStatusText(fields) {
    if (fields.success !== '1') {
        return _('Never updated');
    }
    const parts = [];
    if (fields.update) {
        parts.push(fields.update);
    }
    if (fields.used && fields.total) {
        parts.push(fields.used + ' / ' + fields.total);
    }
    if (fields.expire) {
        parts.push(_('Expires:') + ' ' + fields.expire);
    }
    return parts.join(' | ');
}

// Updating a subscription and reloading the service both rewrite the stored
// status of the subscriptions, while the form keeps showing the values it read
// when the page was loaded. Ask the backend for the stored ones and patch the
// cells in place, so a row updates without a page reload. Reloading uci is not
// an option here, uci.unload() also drops changes that are saved but not yet
// applied.
function refreshSubscriptionStatus() {
    return guarded(function () {
        return gg.subscriptionStatus();
    }).then(function (statuses) {
        for (const section_id in statuses) {
            if (!updateSubscriptionStatusCell(section_id, statuses[section_id])) {
                console.warn('gg: no subscription status cell for %s'.format(section_id));
            }
        }
    }, function (error) {
        // the table is only a view of the stored state, a failed refresh must
        // not turn a successful action into a reported error, but it has to be
        // diagnosable when nothing updates
        console.error('gg: subscription status refresh failed', error);
    });
}

// A rendered section carries its section id in a data-section-id attribute,
// which is also how LuCI locates section elements itself (Map.findElement), and
// the status cell is the one named after the option. GridSection derives from
// TableSection, so the container is a table row with td cells. The same section
// may be rendered more than once, in the table and in a modal popup, so pick
// the container that actually holds the cell. textContent is written so the
// value is never interpreted as markup.
function updateSubscriptionStatusCell(section_id, fields) {
    const containers = document.querySelectorAll('[data-section-id="%s"]'.format(section_id));
    for (const container of containers) {
        const cell = container.querySelector('td[data-name="_stat"]');
        if (cell) {
            cell.textContent = subscriptionStatusText(fields);
            return true;
        }
    }
    return false;
}

function refreshCoreInfo() {
    return guarded(function () {
        return gg.coreInfo();
    }).then(function (info) {
        updateCoreVersion(info.current_version ?? '');
    });
}

function errorMessage(error) {
    return String(error?.message ?? error ?? _('Unknown error'));
}

// Fetches the published versions and writes them into the form. The returned
// promise always settles: guarded() turns a synchronous throw into a rejection,
// and the trailing handler reports failures, so the button's loading state is
// guaranteed to clear. Success needs no notification, the refreshed fields and
// the button settling back are the confirmation.
function runCoreCheck(map, section_id, latestVersions) {
    return guarded(function () {
        return gg.checkCoreUpdate();
    }).then(function (versions) {
        latestVersions.stable = versions.stable ?? '';
        latestVersions.preview = versions.preview ?? '';
        setOptionValue(map, section_id, '_latest_stable_version', latestVersions.stable);
        setOptionValue(map, section_id, '_latest_preview_version', latestVersions.preview);
        if (!latestVersions.stable && !latestVersions.preview) {
            throw new Error(_('Failed to reach GitHub. The release list could not be fetched, please check the network.'));
        }
    }).then(null, function (error) {
        ui.addNotification(null, E('p', [_('Error:'), ' ', errorMessage(error)]), 'danger');
    });
}

// Reads the channel selected in App Config at click time, so the update
// follows whatever is currently chosen without requiring a save first.
// Falls back to stable when the option cannot be read.
function readCoreChannel(map) {
    try {
        const option = map.lookupOption('core_channel', 'config')[0];
        const element = option && option.getUIElement('config');
        const value = element && element.getValue();
        if (value === 'stable' || value === 'preview') {
            return value;
        }
    } catch (e) { /* fall through to the default below */ }
    return 'stable';
}

// form.Button wires onclick through ui.createHandlerFn(), which does
//     t.classList.add('spinning'); t.disabled = true;
//     Promise.resolve(onclick(...)).finally(() => { t.classList.remove('spinning'); ... });
// so the button only leaves its loading state when the returned promise settles,
// and a handler that throws synchronously never gets that far. That internal
// behaviour is outside our control, so no onclick below returns a promise.
function guarded(call) {
    return new Promise(function (resolve) {
        resolve(call());
    });
}

// Runs work that reports its own outcome, from a button handler that returns
// nothing. Returning undefined settles on the next microtask, which clears the
// button's loading state immediately, and everything the user needs to see is
// carried by the notification or the progress dialog instead.
function detached(fn) {
    try {
        fn();
    } catch (error) {
        ui.addNotification(null, E('p', [_('Error:'), ' ', errorMessage(error)]), 'danger');
    }
}

// Buttons are wrapped by ui.createHandlerFn(), which swallows rejections,
// so every outcome has to be reported explicitly here.
function report(promise, successMessage) {
    return promise.then(function () {
        if (successMessage) {
            ui.addNotification(null, E('p', [successMessage]), 'info');
        }
    }, function (error) {
        ui.addNotification(null, E('p', [_('Error:'), ' ', errorMessage(error)]), 'danger');
    });
}

function confirmAction(title, message) {
    return new Promise(function (resolve, reject) {
        ui.showModal(title, [
            E('p', {}, [message]),
            E('div', { 'class': 'right' }, [
                E('button', {
                    'class': 'cbi-button cbi-button-negative',
                    'click': function () {
                        ui.hideModal();
                        reject(new Error(_('Cancelled')));
                    }
                }, _('Cancel')),
                E('button', {
                    'class': 'cbi-button cbi-button-action',
                    'click': function () {
                        ui.hideModal();
                        resolve();
                    }
                }, _('OK'))
            ])
        ]);
    });
}

// hard ceiling on the progress dialog, so the button can never stay spinning
// for ever even if the job or the status call misbehaves
const CORE_UPDATE_TIMEOUT_MS = 30 * 60 * 1000;

function trackCoreUpdate() {
    return new Promise(function (resolve, reject) {
        const output = E('pre', {
            'style': 'max-height: 20em; overflow: auto; white-space: pre-wrap; margin: 0.5em 0 0 0;'
        });

        ui.showModal(_('Core Update'), [
            E('p', {}, [_('The core update is running, this may take a few minutes.')]),
            output
        ]);

        let previous = null;
        let done = false;

        const finish = function (fn, value) {
            if (done) {
                return;
            }
            done = true;
            clearInterval(timer);
            clearTimeout(deadline);
            ui.hideModal();
            fn(value);
        };

        const poll = function () {
            guarded(function () {
                return gg.coreUpdateStatus();
            }).then(function (status) {
                if (status.lines && status.lines.length) {
                    const text = status.lines.join('\n');
                    if (text !== previous) {
                        previous = text;
                        output.textContent = text;
                        output.scrollTop = output.scrollHeight;
                    }
                }
                if (!status.running) {
                    if (status.success) {
                        finish(resolve);
                    } else {
                        finish(reject, new Error(_('The core update failed. Please check the app log for details.')));
                    }
                }
            }, function (error) {
                finish(reject, error);
            });
        };

        const timer = setInterval(poll, 2000);
        const deadline = setTimeout(function () {
            finish(reject, new Error(_('The core update is taking too long. Please check the app log for details.')));
        }, CORE_UPDATE_TIMEOUT_MS);

        poll();
    });
}

function startCoreUpdate(promise) {
    return promise.then(function (result) {
        if (!result?.started) {
            return Promise.reject(new Error(_('Failed to start the core update. Another update may already be running.')));
        }
        return trackCoreUpdate();
    });
}

return view.extend({
    load: function () {
        return Promise.all([
            uci.load('gg'),
            gg.version(),
            gg.status(),
            gg.listProfiles(),
            // resolveDefault so that an unavailable procedure only costs the
            // Core Update section instead of aborting the whole page, which is
            // what Promise.all would do on a rejected call
            L.resolveDefault(gg.coreInfo(), {})
        ]);
    },
    render: function (data) {
        const subscriptions = uci.sections('gg', 'subscription');
        const appVersion = data[1].app ?? '';
        const coreVersion = data[1].core ?? '';
        const running = data[2];
        const profiles = data[3];
        const coreInfo = data[4] ?? {};
        const latestVersions = { stable: '', preview: '' };

        let m, s, o;

        m = new form.Map('gg', _('GG'), _('Core-only manager: subscriptions, core update and service control.'));

        s = m.section(form.TableSection, 'placeholder', _('Status'));
        s.anonymous = true;

        o = s.option(form.Value, '_app_version', _('App Version'));
        o.readonly = true;
        o.load = function () {
            return appVersion;
        };
        o.write = function () { };

        o = s.option(form.DummyValue, '_core_version', _('Core Version'));
        o.cfgvalue = function () {
            return renderCoreVersion(coreVersion);
        };
        o.write = function () { };

        o = s.option(form.DummyValue, '_core_status', _('Core Status'));
        o.cfgvalue = function () {
            return renderStatus(running);
        };
        poll.add(function () {
            return L.resolveDefault(gg.status()).then(function (running) {
                updateStatus(document.getElementById('core_status'), running);
            });
        });

        o = s.option(form.Button, 'reload');
        o.inputstyle = 'action';
        o.inputtitle = _('Reload Service');
        o.onclick = function () {
            // reloading re-fetches remote subscriptions, so the stored status
            // of the rows changed too
            return report(
                guarded(function () {
                    return gg.reload();
                }).then(function () {
                    return refreshSubscriptionStatus();
                }));
        };

        o = s.option(form.Button, 'restart');
        o.inputstyle = 'negative';
        o.inputtitle = _('Restart Service');
        o.onclick = function () {
            return gg.restart();
        };

        s = m.section(form.GridSection, 'subscription', _('Subscriptions'));
        s.addremove = true;
        s.anonymous = true;
        s.sortable = false;

        o = s.option(form.Value, 'name', _('Name'));
        o.rmempty = false;

        o = s.option(form.Value, 'url', _('Subscription URL'));
        o.rmempty = false;

        o = s.option(form.Value, 'info_url', _('Info URL'));
        o.optional = true;
        o.modalonly = true;

        o = s.option(form.Value, 'user_agent', _('User Agent'));
        o.default = 'sing-box';
        o.rmempty = false;
        o.modalonly = true;
        o.value('sing-box');

        o = s.option(form.ListValue, 'prefer', _('Prefer'));
        o.default = 'remote';
        o.value('remote', _('Remote'));
        o.value('local', _('Local'));

        o = s.option(form.DummyValue, '_stat', _('Status'));
        // table only: the modal renders a second copy of the row otherwise
        o.modalonly = false;
        // A grid row renders a child option through renderTextValue() unless it
        // is editable, and that one formats cfgvalue as text, so the value must
        // stay a plain string. The refresh below patches the cell instead.
        o.cfgvalue = function (section_id) {
            return subscriptionStatusText({
                success: uci.get('gg', section_id, 'success'),
                update: uci.get('gg', section_id, 'update'),
                used: uci.get('gg', section_id, 'used'),
                total: uci.get('gg', section_id, 'total'),
                expire: uci.get('gg', section_id, 'expire')
            });
        };

        o = s.option(form.Button, '_refresh');
        o.editable = true;
        o.modalonly = false;
        o.inputstyle = 'positive';
        o.inputtitle = _('Update');
        o.onclick = function (ev, section_id) {
            // the button returning from its loading state is the confirmation,
            // so no success notification, only failures are reported
            return report(
                guarded(function () {
                    return gg.updateSubscription(section_id);
                }).then(function (result) {
                    if (!result?.success) {
                        throw new Error(_('Subscription update failed. Please check the app log for details.'));
                    }
                }).then(function () {
                    return refreshSubscriptionStatus();
                }));
        };

        s = m.section(form.TableSection, 'core_update', _('Core Update'));
        s.anonymous = true;

        o = s.option(form.Value, '_target_architecture', _('Target Architecture'));
        o.readonly = true;
        o.placeholder = _('Unknown');
        o.load = function () {
            return coreInfo.target_arch ?? '';
        };
        o.write = function () { };

        o = s.option(form.Value, '_latest_stable_version', _('Latest Stable Version'));
        o.readonly = true;
        o.placeholder = _('Unknown');
        o.load = function () {
            return latestVersions.stable;
        };
        o.write = function () { };

        o = s.option(form.Value, '_latest_preview_version', _('Latest Preview Version'));
        o.readonly = true;
        o.placeholder = _('Unknown');
        o.load = function () {
            return latestVersions.preview;
        };
        o.write = function () { };

        o = s.option(form.Button, 'check_core_update');
        o.inputstyle = 'action';
        o.inputtitle = _('Check for Updates');
        o.onclick = function (ev, section_id) {
            return guarded(function () {
                return runCoreCheck(m, section_id, latestVersions);
            });
        };

        o = s.option(form.Button, 'update_core');
        o.inputstyle = 'apply';
        o.inputtitle = _('Update Core');
        o.onclick = function () {
            detached(function () {
                const channel = readCoreChannel(m);
                const confirmTitle = (channel === 'preview') ? _('Update To Latest Preview') : _('Update To Latest Stable');
                const confirmMessage = (channel === 'preview')
                    ? _('The sing-box core will be updated to the latest preview release. Preview releases may be unstable.')
                    : _('The sing-box core will be updated to the latest stable release. The service will be restarted once the update is complete.');
                const doneMessage = (channel === 'preview')
                    ? _('The sing-box core is already at the latest preview release, or it has been updated to it.')
                    : _('The sing-box core is already at the latest stable release, or it has been updated to it.');
                report(
                    confirmAction(confirmTitle, confirmMessage)
                        .then(function () {
                            return startCoreUpdate(guarded(function () {
                                return gg.updateCore(channel);
                            }));
                        })
                        .then(function () {
                            return refreshCoreInfo();
                        }),
                    doneMessage);
            });
        };

        s = m.section(form.NamedSection, 'config', 'config', _('App Config'));

        o = s.option(form.Flag, 'enabled', _('Enable'));
        o.rmempty = false;

        o = s.option(form.ListValue, 'profile', _('Choose Profile'));
        o.optional = true;

        for (const profile of profiles) {
            o.value('file:' + profile.name, _('File:') + profile.name);
        };

        for (const subscription of subscriptions) {
            o.value('subscription:' + subscription['.name'], _('Subscription:') + subscription.name);
        };


        o = s.option(form.ListValue, 'core_channel', _('Core Channel'));
        o.value('stable', _('Stable'));
        o.value('preview', _('Preview'));
        o.default = 'stable';
        o.rmempty = false;
        o = s.option(form.Value, 'start_delay', _('Start Delay'));
        o.datatype = 'uinteger';
        o.placeholder = _('Start Immidiately');

        o = s.option(form.Flag, 'scheduled_restart', _('Scheduled Restart'));
        o.rmempty = false;

        o = s.option(form.Value, 'scheduled_restart_cron', _('Scheduled Restart Cron'));
        o.retain = true;
        o.rmempty = false;
        o.depends('scheduled_restart', '1');

        o = s.option(form.Flag, 'test_profile', _('Test Profile'));
        o.rmempty = false;


        s = m.section(form.NamedSection, 'procd', 'procd', _('procd Config'));

        s.tab('general', _('General Config'));

        o = s.taboption('general', form.Flag, 'fast_reload', _('Fast Reload'));
        o.rmempty = false;

        s.tab('rlimit', _('RLIMIT Config'));

        o = s.taboption('rlimit', form.Value, 'rlimit_nproc_soft', _('Number of Processes Soft Limit'));
        o.datatype = 'uinteger';

        o = s.taboption('rlimit', form.Value, 'rlimit_nproc_hard', _('Number of Processes Hard Limit'));
        o.datatype = 'uinteger';

        o = s.taboption('rlimit', form.Value, 'rlimit_address_space_soft', _('Address Space Size Soft Limit'));
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        o = s.taboption('rlimit', form.Value, 'rlimit_address_space_hard', _('Address Space Size Hard Limit'));
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        o = s.taboption('rlimit', form.Value, 'rlimit_data_soft', _('Heap Size Soft Limit'));
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        o = s.taboption('rlimit', form.Value, 'rlimit_data_hard', _('Heap Size Hard Limit'));
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        o = s.taboption('rlimit', form.Value, 'rlimit_stack_soft', _('Stack Size Soft Limit'));
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        o = s.taboption('rlimit', form.Value, 'rlimit_stack_hard', _('Stack Size Hard Limit'));
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        o = s.taboption('rlimit', form.Value, 'rlimit_nofile_soft', _('Number of Open Files Soft Limit'));
        o.datatype = 'uinteger';

        o = s.taboption('rlimit', form.Value, 'rlimit_nofile_hard', _('Number of Open Files Hard Limit'));
        o.datatype = 'uinteger';

        s.tab('environment_variable', _('Environment Variable Config'));

        o = s.taboption('environment_variable', form.Value, 'env_go_max_procs', 'GOMAXPROCS');
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        o = s.taboption('environment_variable', form.Value, 'env_go_mem_limit', 'GOMEMLIMIT');
        o.datatype = 'uinteger';
        o.placeholder = _('Unlimited');

        return m.render();
    }
});
