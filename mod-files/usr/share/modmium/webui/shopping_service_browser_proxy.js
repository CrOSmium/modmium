import 'chrome://resources/ash/common/cr_elements/cr_button/cr_button.js';
import 'chrome://resources/ash/common/cr_elements/cr_dialog/cr_dialog.js';
import 'chrome://resources/ash/common/cr_elements/cr_drawer/cr_drawer.js';
import 'chrome://resources/ash/common/cr_elements/cr_icon_button/cr_icon_button.js';
import 'chrome://resources/ash/common/cr_elements/cr_icons.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_hidden_style.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_page_host_style.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_shared_style.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_input/cr_input.js';
import 'chrome://resources/ash/common/cr_elements/cr_link_row/cr_link_row.js';
import 'chrome://resources/ash/common/cr_elements/md_select.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_textarea/cr_textarea.js';
import 'chrome://resources/ash/common/cr_elements/cr_toast/cr_toast.js';
import 'chrome://resources/ash/common/cr_elements/cr_toggle/cr_toggle.js';
import 'chrome://resources/ash/common/cr_elements/cr_toolbar/cr_toolbar_search_field.js';
import 'chrome://resources/ash/common/cr_elements/icons.html.js';
import 'chrome://resources/ash/common/cr_elements/cr_shared_vars.css.js';
import 'chrome://resources/ash/common/cr_elements/cros_color_overrides.css.js';
import 'chrome://resources/polymer/v3_0/iron-icon/iron-icon.js';
import 'chrome://resources/polymer/v3_0/iron-iconset-svg/iron-iconset-svg.js';
import 'chrome://resources/polymer/v3_0/iron-dropdown/iron-dropdown.js';
import 'chrome://resources/polymer/v3_0/iron-media-query/iron-media-query.js';
import 'chrome://resources/polymer/v3_0/iron-selector/iron-selector.js';
import 'chrome://resources/polymer/v3_0/paper-tooltip/paper-tooltip.js';
import {ColorChangeUpdater} from 'chrome://resources/cr_components/color_change_listener/colors_css_updater.js';
import {html, PolymerElement} from 'chrome://resources/polymer/v3_0/polymer/polymer_bundled.min.js';

const MENU_ITEMS = [
  {path: 'manager', label: 'Manager', icon: 'modmium:chrome'},
  {path: 'policies', label: 'Policies', icon: 'modmium:auth-key'},
  {path: 'apps', label: 'Apps', icon: 'modmium:apps'},
  {path: 'misc', label: 'Misc', icon: 'modmium:system-preferences'},
];

const GUI_PAGE_OVERRIDES = {
  manager: [
    {
      header: 'Modmium',
      rows: [
        {label: 'Nightly', status: true, detail: 'update', action: 'Check for updates', primary: true},
        {label: 'ChromeOS version', sublabel: '152', detail: 'version'},
        {label: 'Shell', sublabel: 'bash', detail: 'shell'},
        {label: 'Source repository', sublabel: 'CrOSmium/modmium', detail: 'repository'},
        {label: 'Boot priority', sublabel: 'Root A', detail: 'boot'},
      ],
    },
    {
      header: 'Device',
      rows: [
        {label: 'Enrollment', sublabel: 'Enabled', detail: 'enrollment'},
        {label: 'Local account', detail: 'account'},
        {label: 'Feature toggles', detail: 'features'},
      ],
    },
  ],
  policies: [
    {
      header: 'Policies',
      rows: [
        {label: 'Device policies', sublabel: 'Restrictions, reporting, enterprise, misc', detail: 'device-policies'},
        {label: 'User policies', sublabel: 'policy.json', detail: 'user-policies'},
      ],
    },
  ],
  apps: [
    {
      header: 'MOSH apps',
      rows: [
        {label: 'apps.conf', sublabel: 'Commands shown in the MOSH Apps menu', detail: 'apps-config'},
      ],
    },
  ],
  misc: [
    {
      header: 'Misc',
      rows: [
        {label: 'Bootsplash', detail: 'bootsplash'},
        {label: 'Cr3nroll', detail: 'cr3nroll'},
        {label: 'Emergency revert', detail: 'revert'},
        {label: 'Nix', detail: 'nix'},
        {label: 'Ashland', detail: 'ashland'},
        {label: 'Credits', detail: 'credits'},
      ],
    },
  ],
};

function genericMenuCards(menu) {
  if (!menu) return [];
  return [{
    header: menu.title,
    rows: menu.items
      .filter(item => item.id.split('.').at(-1) !== 'exit')
      .map(item => ({
        label: item.label,
        detail: item.view || '',
        actions: !item.view && item.enabled ? [{
          label: 'Run',
          moshMenu: menu.id,
          moshAction: item.id,
        }] : [],
      })),
  }];
}

const DETAIL_DATA = {
  update: {
    page: 'manager', title: 'Update Modmium', cards: [{rows: [
      {label: 'Current build', sublabel: 'Modmium nightly', actions: [{label: 'Check now', primary: true, message: 'Update check started'}]},
    ]}],
  },
  version: {
    page: 'manager', title: 'ChromeOS version', cards: [{rows: [
      {label: 'ChromeOS version', kind: 'select', options: ['152', '151', '150'], value: '152'},
      {actions: [{label: 'Continue', primary: true, message: 'ChromeOS version selected'}]},
    ]}],
  },
  shell: {
    page: 'manager', title: 'Shell', cards: [{rows: [
      {label: 'Shell executable', kind: 'input', value: 'bash', actions: [
        {label: 'Save', primary: true, message: 'Shell saved', moshAction: 'shell.set'},
      ]},
    ]}],
  },
  repository: {
    page: 'manager', title: 'Source repository', cards: [{rows: [
      {label: 'Repository URL', kind: 'input', value: 'https://github.com/CrOSmium/modmium', actions: [
        {label: 'Save', primary: true, danger: true, prompt: 'Use this update repository?',
          message: 'Repository saved', moshAction: 'repository.set', args: ['true']},
      ]},
      {label: 'Official repository', actions: [
        {label: 'Reset', danger: true, prompt: 'Reset to the official Modmium repository?',
          message: 'Repository reset', moshAction: 'repository.reset', args: ['true']},
      ]},
    ]}],
  },
  boot: {
    page: 'manager', title: 'Boot priority', cards: [{rows: [
      {label: 'Current boot root', sublabel: 'Root A', actions: [{label: 'Swap priority', primary: true, message: 'Boot priority swapped'}]},
    ]}],
  },
  enrollment: {
    page: 'manager', title: 'Enrollment', cards: [{rows: [
      {label: 'Enrollment', sublabel: 'Enabled', actions: [{label: 'Disable enrollment', danger: true, message: 'Disable enrollment?'}]},
    ]}],
  },
  account: {
    page: 'manager', title: 'Add local account', cards: [{rows: [
      {label: 'Username', kind: 'input'},
      {label: 'Domain', kind: 'input', value: 'modmium.dev'},
      {label: 'Display name', kind: 'input'},
      {label: 'Password', kind: 'password'},
      {actions: [{label: 'Create account', primary: true, message: 'Local account ready to create'}]},
    ]}],
  },
  features: {
    page: 'manager', title: 'Feature toggles', cards: [{rows: [
      {label: 'Chromebook Plus features', kind: 'toggle'},
      {label: 'Studio Mic', kind: 'toggle'},
      {label: 'System Blur', kind: 'toggle', checked: true},
    ]}],
  },
  'device-policies': {
    page: 'policies', title: 'Device policies', cards: [{header: 'Policy categories', rows: [
      {label: 'Restrictions', actions: [{label: 'Edit', message: 'Restrictions opened'}]},
      {label: 'Reporting', actions: [{label: 'Edit', message: 'Reporting opened'}]},
      {label: 'Enterprise settings', actions: [{label: 'Edit', message: 'Enterprise settings opened'}]},
      {label: 'Misc', actions: [{label: 'Edit', message: 'Misc policies opened'}]},
      {actions: [{label: 'Reset changes', danger: true, message: 'Reset policy changes?'}, {label: 'Apply policies', primary: true, message: 'Device policies applied'}]},
    ]}],
  },
  'user-policies': {
    page: 'policies', title: 'User policies', cards: [{rows: [
      {label: 'Policy file', sublabel: 'No policy.json loaded', actions: [{label: 'Grab from Downloads', message: 'Policy import selected'}]},
      {label: 'Current account', actions: [{label: 'Extract policies', message: 'Policy extraction selected'}]},
      {label: 'Policy editor', actions: [{label: 'Run editor', primary: true, message: 'User policy editor selected'}]},
      {label: 'Editor installation', actions: [{label: 'Reinstall', message: 'Policy editor reinstall selected'}]},
    ]}],
  },
  'apps-config': {
    page: 'apps', title: 'Apps', cards: [{header: 'apps.conf', rows: [
      {kind: 'textarea', value: 'nano /usr/local/config/apps.conf | Edit apps.conf'},
      {sublabel: 'COMMAND | NAME · Maximum 9 entries', actions: [{label: 'Save', primary: true, message: 'Apps configuration saved'}]},
    ]}],
  },
  bootsplash: {
    page: 'misc', title: 'Bootsplash', cards: [{rows: [
      {label: 'Modmium bootsplash', actions: [{label: 'Replace', message: 'Modmium bootsplash selected'}]},
      {label: 'Custom image', actions: [{label: 'Choose', message: 'Custom image selected'}]},
      {label: 'Stock bootsplash', actions: [{label: 'Restore', message: 'Stock bootsplash restored'}, {label: 'Download backup', message: 'Stock bootsplash backup selected'}]},
      {label: 'Installed bootsplash', actions: [{label: 'Remove', danger: true, message: 'Remove the installed bootsplash?'}]},
    ]}],
  },
  cr3nroll: {
    page: 'misc', title: 'Cr3nroll', cards: [{rows: [
      {label: 'Current enrollment keys', actions: [{label: 'Save', message: 'Enrollment keys saved'}]},
      {label: 'Saved enrollment keys', actions: [{label: 'Load', message: 'Saved keys selected'}]},
      {label: 'New enrollment keys', actions: [{label: 'Generate', message: 'Key generation selected'}]},
      {label: 'Enrollment info', actions: [{label: 'Import', message: 'Enrollment import selected'}, {label: 'Backup', message: 'Enrollment backup selected'}]},
    ]}],
  },
  revert: {
    page: 'misc', title: 'Emergency revert', cards: [{rows: [
      {label: 'Full factory revert', actions: [{label: 'Restore OS and MPkeys', danger: true, message: 'Restore ChromeOS and MPkeys?'}]},
      {label: 'ChromeOS', actions: [{label: 'Restore OS', danger: true, message: 'Restore ChromeOS?'}]},
      {label: 'MPkeys', actions: [{label: 'Revert MPkeys', danger: true, message: 'Revert MPkeys?'}]},
    ]}],
  },
  nix: {
    page: 'misc', title: 'Nix', cards: [{rows: [
      {label: 'Nix', actions: [{label: 'Install', primary: true, message: 'Nix installation selected'}]},
      {label: 'Mix', actions: [{label: 'Update', message: 'Mix update selected'}]},
    ]}],
  },
  ashland: {
    page: 'misc', title: 'Ashland', cards: [{rows: [
      {label: 'Ashland', actions: [{label: 'Install', primary: true, message: 'Ashland installation selected'}]},
      {label: 'Run Ashland', kind: 'toggle'},
      {label: 'Autostart on reboot', kind: 'toggle'},
    ]}],
  },
  credits: {
    page: 'misc', title: 'Credits', cards: [{header: 'Created by CrOSmium.dev and crosbreaker.com', rows: [
      {label: 'Individual Credits:'},
      {label: 'dmd:', sublabel: 'Project lead; made MOSH/libmosh (and its subMOSHes), base devfw & MPkeys manager, mix, chromeos-setdevpasswd, base ChromeOS version switcher, post kxtzownsu code review, and lots of small changes, and continually maintaining the project after official release [06-07-2026].'},
      {label: 'mariahscarycarey:', sublabel: '(Former) Lead developer; made image builder, device policy editor frontend, ChromeOS version switcher, did most bugfixing, some maintaining up until 06-17-2026, and MANY small changes to other code.'},
      {label: 'lxrd:', sublabel: 'Discovered policy-test-tool and created device policy editing script, made a script to let us stream ChromeOS updates, integrated nix into Modmium.'},
      {label: 'codenerd87:', sublabel: 'Wrote code for restoring MPkeys, fixed devfw flashing on geralt, firmware manager'},
      {label: 'kxtzownsu:', sublabel: "Did early code review to make sure we weren't skidding until he stepped down [05-26-2026]."},
      {label: 'xz8f:', sublabel: 'Helped with custom bootsplashes.'},
      {label: 'Casper1051, Moonstone, pilgorr:', sublabel: 'creating the default bootsplashes.'},
      {label: 'pers5124, dinonuget_, spacenerd1235, xmb9:', sublabel: 'private beta testers, found and reported lots of bugs.'},
      {label: '[ Removing this menu from Modmium is not permitted ]'},
    ]}],
  },
};

const SEARCH_ENTRIES = [
  ...MENU_ITEMS.map(item => ({
    label: item.label,
    page: item.path,
    detail: '',
    icon: item.icon,
  })),
  ...Object.entries(DETAIL_DATA).map(([detail, data]) => ({
    label: data.title,
    page: data.page,
    detail,
    icon: MENU_ITEMS.find(item => item.path === data.page).icon,
  })),
];

class ModmiumIconsElement extends PolymerElement {
  static get is() { return 'modmium-icons'; }
  static get template() {
    return html`
      <iron-iconset-svg name="modmium" size="20">
        <svg><defs>
          <g id="chrome" viewBox="0 0 20 20">
            <path d="M17.418 6.25h-7.417c-1.833 0-3.416 1.417-3.666 3.166l-2.75-4.75c1.5-1.833 3.833-3 6.416-3 3.25 0 6.084 1.834 7.417 4.584Z"></path>
            <path d="M6.751 11.833c.667 1.167 1.834 1.917 3.25 1.917.5 0 .917-.084 1.417-.25l-2.75 4.75c-4-.667-7-4.084-7-8.25 0-1.667.5-3.25 1.333-4.583l3.75 6.416Z"></path>
            <path d="M13.751 10c0 .666-.166 1.333-.5 1.833l-3.75 6.5h.5c4.584 0 8.334-3.75 8.334-8.333 0-1-.167-2-.5-2.917h-5.5c.833.667 1.416 1.75 1.416 2.917Z"></path>
            <path d="M12.918 10a2.917 2.917 0 1 1-5.833 0 2.917 2.917 0 0 1 5.833 0Z"></path>
          </g>
          <g id="auth-key">
            <path d="M6.364 5C3.956 5 2 7.018 2 9.5S3.956 14 6.364 14c1.898 0 3.512-1.252 4.11-3H13.5v3h3v-3H18V8h-7.527c-.597-1.747-2.21-3-4.11-3zm0 6c-.8 0-1.455-.675-1.455-1.5S5.563 8 6.363 8c.8 0 1.454.675 1.454 1.5S7.164 11 6.364 11z"></path>
          </g>
          <g id="apps" viewBox="0 0 20 20">
            <path d="M15 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM5 17a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm10 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm-5 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM5 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm5 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm5 5a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM5 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm5 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"></path>
          </g>
          <g id="system-preferences" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.519 18h2.96c.59 0 1.087-.422 1.167-.953l.216-1.491.623-.36 1.44.563c.552.21 1.168-.008 1.44-.492l1.487-2.514a1.127 1.127 0 0 0-.296-1.453l-1.215-.93.016-.358-.016-.36 1.215-.929a1.13 1.13 0 0 0 .288-1.468l-1.471-2.483c-.272-.484-.888-.71-1.456-.507l-1.44.562-.631-.36-.216-1.475c-.072-.57-.568-.992-1.16-.992H8.511c-.584 0-1.08.43-1.152.976l-.216 1.492-.623.359-1.448-.57c-.544-.211-1.16.008-1.432.492L2.16 7.74a1.106 1.106 0 0 0 .297 1.469l1.215.929-.016.36.016.358-1.223.93c-.448.343-.568.952-.288 1.468l1.463 2.475c.272.484.888.71 1.448.508l1.44-.563.631.36.216 1.475c.072.57.568.992 1.16.992ZM10 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"></path>
          </g>
        </defs></svg>
      </iron-iconset-svg>
    `;
  }
}
customElements.define(ModmiumIconsElement.is, ModmiumIconsElement);

class SettingsCardElement extends PolymerElement {
  static get is() { return 'settings-card'; }
  static get properties() { return {headerText: String}; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          --settings-card-bg-color: var(--cros-sys-app_base);
          --settings-card-border-radius: 16px;
          display: flex;
          flex-direction: column;
          margin-bottom: 16px;
          outline: none;
          position: relative;
        }
        @media (prefers-color-scheme: dark) {
          :host { --settings-card-bg-color: var(--cros-sys-surface1); }
        }
        #header { margin: 0; padding: 8px; }
        #headerText {
          color: var(--cros-sys-primary);
          font: var(--cros-button-2-font);
          margin: 0;
        }
        #card {
          background-color: var(--settings-card-bg-color);
          border-radius: var(--settings-card-border-radius);
          flex: 1;
          overflow: hidden;
        }
      </style>
      <template is="dom-if" if="[[headerText]]">
        <div id="header"><h2 id="headerText">[[headerText]]</h2></div>
      </template>
      <div id="card"><slot></slot></div>
    `;
  }
}
customElements.define(SettingsCardElement.is, SettingsCardElement);

class ModmiumSettingsRowElement extends PolymerElement {
  static get is() { return 'modmium-settings-row'; }
  static get properties() { return {item: Object}; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides md-select">
        :host { display: block; }
        .settings-box {
          align-items: center;
          border-top: var(--cr-separator-line);
          display: flex;
          min-height: var(--settings-row-min-height);
          padding: 0 var(--cr-section-padding);
        }
        :host(:first-child) .settings-box { border-top: none; }
        .start { flex: 1; min-width: 0; }
        .settings-box-text {
          box-sizing: border-box;
          padding-block: var(--cr-section-vertical-padding);
          padding-inline-end: 20px;
        }
        .label { color: var(--cros-sys-on_surface); }
        .secondary {
          color: var(--cr-secondary-text-color);
          font-weight: 400;
          white-space: pre-wrap;
        }
        .secondary:empty { display: none; }
        .actions { align-items: center; display: flex; gap: 8px; }
        cr-input { min-width: 280px; }
        cr-textarea { margin: 12px 0; width: 100%; }
        select { --md-select-width: 180px; }
        cr-button.danger { color: var(--cros-sys-error); }
        cr-link-row { min-height: var(--settings-row-min-height); }
      </style>

      <template is="dom-if" if="[[_isLink(item)]]">
        <cr-link-row label="[[item.label]]" sub-label="[[item.sublabel]]"
            on-click="_openDetail" role-description="Subpage">
        </cr-link-row>
      </template>

      <template is="dom-if" if="[[!_isLink(item)]]">
        <div class="settings-box">
          <div class="start settings-box-text">
            <div class="label">[[item.label]]</div>
            <div class="secondary">[[item.sublabel]]</div>
          </div>

          <template is="dom-if" if="[[_isInput(item)]]">
            <cr-input value="[[item.value]]" aria-label$="[[item.label]]"></cr-input>
          </template>
          <template is="dom-if" if="[[_isPassword(item)]]">
            <cr-input type="password" aria-label$="[[item.label]]"></cr-input>
          </template>
          <template is="dom-if" if="[[_isSelect(item)]]">
            <select class="md-select" aria-label$="[[item.label]]">
              <template is="dom-repeat" items="[[item.options]]" as="option">
                <option selected$="[[_selected(option, item.value)]]">[[option]]</option>
              </template>
            </select>
          </template>
          <template is="dom-if" if="[[_isToggle(item)]]">
            <cr-toggle checked="[[item.checked]]" aria-label$="[[item.label]]"></cr-toggle>
          </template>
          <template is="dom-if" if="[[_isTextarea(item)]]">
            <cr-textarea value="[[item.value]]" aria-label="MOSH apps configuration"></cr-textarea>
          </template>
          <template is="dom-if" if="[[item.actions.length]]">
            <div class="actions">
              <template is="dom-repeat" items="[[item.actions]]" as="action">
                <cr-button class$="[[_buttonClass(action)]]" on-click="_runAction">
                  [[action.label]]
                </cr-button>
              </template>
            </div>
          </template>
        </div>
      </template>
    `;
  }
  _isLink(item) { return Boolean(item && item.detail); }
  _isInput(item) { return item?.kind === 'input'; }
  _isPassword(item) { return item?.kind === 'password'; }
  _isSelect(item) { return item?.kind === 'select'; }
  _isToggle(item) { return item?.kind === 'toggle'; }
  _isTextarea(item) { return item?.kind === 'textarea'; }
  _selected(option, value) { return option === value; }
  _buttonClass(action) {
    return [action.primary ? 'action-button' : '', action.danger ? 'danger' : '']
      .filter(Boolean).join(' ');
  }
  _openDetail() {
    this.dispatchEvent(new CustomEvent('modmium-open-detail', {
      bubbles: true, composed: true, detail: this.item.detail,
    }));
  }
  _runAction(event) {
    const action = {...event.model.action};
    const control = this.shadowRoot.querySelector('cr-input, select, cr-textarea');
    action.args = control ? [control.value, ...(action.args || [])] : action.args || [];
    this.dispatchEvent(new CustomEvent('modmium-action', {
      bubbles: true, composed: true, detail: action,
    }));
  }
}
customElements.define(ModmiumSettingsRowElement.is, ModmiumSettingsRowElement);

class OsSettingsMenuItemElement extends PolymerElement {
  static get is() { return 'os-settings-menu-item'; }
  static get properties() {
    return {
      path: {type: String, reflectToAttribute: true},
      icon: String,
      label: String,
      sublabel: String,
    };
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          --tap-target-padding: 3px;
          align-items: center;
          background: transparent;
          border: var(--settings-menu-item-border-width) solid transparent;
          border-radius: 16px;
          box-sizing: border-box;
          color: var(--cros-text-color-primary);
          cursor: pointer;
          display: flex;
          flex-direction: row;
          font: var(--cros-button-1-font);
          height: 60px;
          padding-inline: calc(12px - var(--settings-menu-item-border-width));
          text-decoration: none;
          width: var(--settings-menu-item-width);
        }
        #labelWrapper { flex-grow: 1; max-width: 200px; }
        #label, #sublabel { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        #sublabel { color: var(--cros-sys-on_surface_variant); font: var(--cros-body-2-font); }
        iron-icon { margin-inline-end: 12px; pointer-events: none; }
        :host(:not(.iron-selected)) iron-icon { --iron-icon-fill-color: var(--cros-sys-primary); }
        :host(:not(.iron-selected):hover) { background-color: var(--cros-sys-hover_on_subtle) !important; }
        :host-context(.focus-outline-visible):host(:focus) { border-color: var(--cros-focus-ring-color); }
        :host(.iron-selected) { background-color: var(--cros-sys-primary) !important; color: var(--cros-sys-on_primary); }
        :host(.iron-selected) iron-icon { --iron-icon-fill-color: var(--cros-sys-on_primary); }
        :host(.iron-selected) #sublabel { color: var(--cros-sys-surface_variant); }
      </style>
      <iron-icon icon="[[icon]]"></iron-icon>
      <div id="labelWrapper">
        <div id="label">[[label]]</div>
        <div id="sublabel">[[sublabel]]</div>
      </div>
      <paper-tooltip position="right" offset="4" fit-to-visible-bounds
          animation-delay="1000" aria-hidden="true">[[label]]</paper-tooltip>
    `;
  }
  ready() {
    super.ready();
    this.setAttribute('role', 'link');
    this.setAttribute('tabindex', '0');
    this.addEventListener('keydown', event => {
      if ((event.key === 'Enter' || event.key === ' ') && !event.repeat) {
        event.preventDefault();
        this.click();
      }
    });
  }
}
customElements.define(OsSettingsMenuItemElement.is, OsSettingsMenuItemElement);

class OsSettingsMenuElement extends PolymerElement {
  static get is() { return 'os-settings-menu'; }
  static get properties() { return {items: Array, selectedPath: String}; }
  constructor() {
    super();
    this.items = MENU_ITEMS;
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          box-sizing: border-box;
          display: block;
          padding-bottom: 2px;
          padding-inline-end: var(--settings-menu-padding-inline-end);
          padding-inline-start: var(--settings-menu-padding-inline-start);
          padding-top: var(--settings-menu-padding-top);
          width: var(--settings-menu-width);
        }
        :host * { -webkit-tap-highlight-color: transparent; }
        [selectable] > :focus { background-color: transparent; }
        #topMenu > os-settings-menu-item { margin-bottom: 8px; }
        #topMenu > os-settings-menu-item:last-of-type {
          margin-bottom: calc(48px - calc(var(--tap-target-padding) + var(--settings-menu-item-border-width)));
        }
      </style>
      <iron-selector id="topMenu" role="navigation"
          selectable="os-settings-menu-item" attr-for-selected="path"
          selected="[[selectedPath]]" on-iron-activate="_activate">
        <template is="dom-repeat" items="[[items]]" as="item">
          <os-settings-menu-item path="[[item.path]]" icon="[[item.icon]]"
              label="[[item.label]]" sublabel="[[item.sublabel]]">
          </os-settings-menu-item>
        </template>
      </iron-selector>
    `;
  }
  _activate(event) {
    this.dispatchEvent(new CustomEvent('modmium-navigate', {
      bubbles: true, composed: true, detail: event.detail.item.path,
    }));
  }
}
customElements.define(OsSettingsMenuElement.is, OsSettingsMenuElement);

class OsSearchResultRowElement extends PolymerElement {
  static get is() { return 'os-search-result-row'; }
  static get properties() {
    return {
      result: Object,
      selected: {type: Boolean, reflectToAttribute: true},
    };
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host { display: block; width: 100%; }
        :host([selected]) #searchResultContainer {
          background-color: var(--cros-sys-highlight_shape);
        }
        :host(:not([selected])) #searchResultContainer:hover {
          background-color: var(--cros-sys-hover_on_subtle);
        }
        #searchResultContainer {
          align-items: center;
          color: var(--cros-sys-on_surface);
          cursor: pointer;
          display: flex;
          font: var(--cros-body-2-font);
          height: 48px;
          justify-content: center;
          outline: none;
          width: inherit;
        }
        #resultText { flex-grow: 1; margin: var(--cr-toolbar-search-field-term-margin); }
        iron-icon {
          --iron-icon-fill-color: var(--cros-sys-primary);
          margin: var(--cr-toolbar-icon-margin);
          width: var(--cr-toolbar-icon-container-size);
        }
      </style>
      <div id="searchResultContainer" role="option" on-click="_open">
        <iron-icon icon="[[result.icon]]"></iron-icon>
        <div id="resultText">[[result.label]]</div>
        <iron-icon icon="cr:arrow-forward"></iron-icon>
      </div>
    `;
  }
  _open() {
    this.dispatchEvent(new CustomEvent('modmium-search-select', {
      bubbles: true,
      composed: true,
      detail: this.result,
    }));
  }
}
customElements.define(OsSearchResultRowElement.is, OsSearchResultRowElement);

class OsSettingsSearchBoxElement extends PolymerElement {
  static get is() { return 'os-settings-search-box'; }
  static get properties() {
    return {
      narrow: {type: Boolean, reflectToAttribute: true},
      showingSearch: {type: Boolean, value: false, notify: true, reflectToAttribute: true},
      hasSearchQuery: {type: Boolean, value: false, reflectToAttribute: true},
      query: {type: String, value: ''},
      results: {type: Array, value: () => []},
      selectedResult: {type: Number, value: 0},
      shouldShowDropdown: {type: Boolean, value: false, reflectToAttribute: true},
    };
  }
  static get observers() { return ['_resultsChanged(results.*, query)']; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          --cr-toolbar-search-field-background: var(--cros-sys-input_field_on_shaded);
          --cr-toolbar-focused-min-height: 40px;
          --cr-toolbar-icon-container-size: 32px;
          --cr-toolbar-icon-margin: 8px 16px;
          --cr-toolbar-search-field-icon-opacity: 1;
          --cr-toolbar-search-field-narrow-mode-prompt-opacity: 1;
          --cr-toolbar-search-field-prompt-opacity: 1;
          --cr-toolbar-search-icon-margin-inline-start: 16px;
          --cr-toolbar-query-exists-min-height: var(--cr-toolbar-focused-min-height);
          --separator-height: 8px;
          -webkit-tap-highlight-color: transparent;
          display: flex;
          flex-basis: var(--cr-toolbar-field-width);
          transition: width 150ms cubic-bezier(.4, 0, .2, 1);
          width: var(--cr-toolbar-field-width);
        }
        :host([narrow]:not([showing-search])) {
          flex-direction: row;
          justify-content: flex-end;
        }
        :host([narrow][showing-search]) { justify-content: center; }
        cr-toolbar-search-field {
          --cr-toolbar-search-field-term-margin: 0;
          --cr-toolbar-search-field-border-radius: var(--settings-toolbar-search-field-border-radius);
          --cr-toolbar-search-field-paper-spinner-margin: 0 12px;
          --cr-toolbar-search-field-input-icon-color: var(--cros-icon-color-primary);
          --cr-toolbar-search-field-input-text-color: var(--cros-text-color-primary);
          --cr-toolbar-search-field-input-caret-color: currentColor;
          --cr-toolbar-search-field-prompt-color: var(--cros-text-color-secondary);
          --cr-toolbar-icon-button-focus-outline-color: var(--cros-focus-ring-color);
          --cr-toolbar-field-max-width: var(--cr-toolbar-field-width);
          font: var(--cros-body-2-font);
          height: var(--settings-toolbar-search-box-height);
        }
        :host([narrow][showing-search]) cr-toolbar-search-field {
          background-color: var(--cr-toolbar-search-field-background);
        }
        :host([narrow]:not([showing-search])) cr-toolbar-search-field {
          padding-inline-end: var(--settings-toolbar-padding-inline-end);
        }
        :host([showing-search]:focus-within) cr-toolbar-search-field {
          --cr-toolbar-search-field-background: var(--cros-bg-color-elevation-3);
          box-shadow: var(--cr-elevation-1);
          min-height: var(--cr-toolbar-focused-min-height);
        }
        :host([has-search-query]) cr-toolbar-search-field {
          min-height: var(--cr-toolbar-query-exists-min-height);
        }
        :host(:not(:focus-within)) cr-toolbar-search-field {
          --cr-toolbar-search-field-cursor: pointer;
        }
        :host([should-show-dropdown]:focus-within) cr-toolbar-search-field {
          --cr-toolbar-search-field-border-radius: 20px 20px 0 0;
          box-shadow: var(--cr-elevation-3);
          height: 56px;
          margin-top: var(--separator-height);
          padding-bottom: var(--separator-height);
        }
        :host-context([chrome-refresh-2023]) cr-toolbar-search-field { outline-offset: 0; }
        :host-context([chrome-refresh-2023]):host-context(
            html:not(.focus-outline-visible)) cr-toolbar-search-field,
        :host-context([chrome-refresh-2023]):host([showing-search])
            cr-toolbar-search-field { outline: none; }
        iron-dropdown { margin-top: 72px; }
        iron-dropdown [slot='dropdown-content'] {
          background-color: var(--cros-bg-color-elevation-3);
          border-radius: 0 0 20px 20px;
          box-shadow: var(--cr-elevation-3);
          display: table;
          padding-bottom: 8px;
          width: var(--cr-toolbar-field-width);
        }
        #noSearchResultsContainer {
          font: var(--cros-body-2-font);
          height: 32px;
          line-height: 32px;
          margin-inline-start: 24px;
        }
        .separator {
          background-color: var(--cros-bg-color-elevation-3);
          border-top: 1px solid var(--cros-sys-separator);
          height: var(--separator-height);
          margin: -9px 0 0;
        }
      </style>
      <cr-toolbar-search-field id="search" narrow="[[narrow]]"
          label="Search settings" clear-label="Clear search"
          showing-search="{{showingSearch}}" on-search-icon-clicked="_searchIconClicked">
      </cr-toolbar-search-field>
      <iron-dropdown id="searchResults" opened="[[shouldShowDropdown]]"
          allow-outside-scroll no-cancel-on-outside-click>
        <div slot="dropdown-content" role="listbox">
          <div class="separator"></div>
          <template is="dom-repeat" items="[[results]]" as="result" index-as="index">
            <os-search-result-row result="[[result]]"
                selected="[[_isSelected(index, selectedResult)]]">
            </os-search-result-row>
          </template>
          <div id="noSearchResultsContainer" hidden$="[[results.length]]">
            No results found
          </div>
        </div>
      </iron-dropdown>
    `;
  }
  ready() {
    super.ready();
    const input = this.$.search.getSearchInput();
    input.addEventListener('input', () => this._setQuery(input.value));
    input.addEventListener('focus', () => {
      this.showingSearch = true;
      this.shouldShowDropdown = Boolean(this.query);
    });
    input.addEventListener('mousedown', () => {
      if (!this.shouldShowDropdown && this.query) requestAnimationFrame(() => input.select());
    });
    this.addEventListener('keydown', event => this._keydown(event));
    this.addEventListener('focusout', event => {
      if (!this.contains(event.relatedTarget)) this.shouldShowDropdown = false;
    });
    this.addEventListener('modmium-search-select', () => this.clear());
  }
  clear() {
    this.$.search.setValue('');
    this._setQuery('');
    this.shouldShowDropdown = false;
    this.showingSearch = false;
  }
  _setQuery(query) {
    this.query = query;
    this.hasSearchQuery = Boolean(query.trim());
    this.selectedResult = 0;
    this.shouldShowDropdown = this.hasSearchQuery && this.$.search.isSearchFocused();
    this.dispatchEvent(new CustomEvent('modmium-search', {
      bubbles: true,
      composed: true,
      detail: query,
    }));
  }
  _resultsChanged() {
    this.selectedResult = 0;
    this.shouldShowDropdown = Boolean(this.query) && this.$?.search?.isSearchFocused();
  }
  _isSelected(index, selected) { return index === selected; }
  _keydown(event) {
    if (!this.shouldShowDropdown || !this.results.length) return;
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const step = event.key === 'ArrowUp' ? -1 : 1;
      this.selectedResult =
          (this.selectedResult + this.results.length + step) % this.results.length;
    } else if (event.key === 'Enter') {
      event.preventDefault();
      this.dispatchEvent(new CustomEvent('modmium-search-select', {
        bubbles: true,
        composed: true,
        detail: this.results[this.selectedResult],
      }));
    } else if (event.key === 'Escape') {
      this.clear();
    }
  }
  _searchIconClicked() {
    this.$.search.getSearchInput().select();
    this.shouldShowDropdown = Boolean(this.query);
  }
}
customElements.define(OsSettingsSearchBoxElement.is, OsSettingsSearchBoxElement);

class SettingsToolbarElement extends PolymerElement {
  static get is() { return 'settings-toolbar'; }
  static get properties() {
    return {
      results: {type: Array, value: () => []},
      query: {type: String, value: ''},
      narrow: {type: Boolean, reflectToAttribute: true},
      showingSearch: {type: Boolean, reflectToAttribute: true},
      isSearchBoxCutoff: {type: Boolean, reflectToAttribute: true},
    };
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides cr-icons cr-hidden-style">
        :host {
          align-items: center;
          background-color: var(--settings-base-bg-color);
          color: var(--cros-text-color-secondary);
          display: flex;
          height: var(--settings-toolbar-height);
          min-height: 56px;
          padding-top: var(--settings-toolbar-padding-top);
          z-index: 3;
        }
        h1 {
          color: var(--cros-sys-primary);
          flex: 1;
          font: var(--cros-title-1-font);
          margin-inline-start: 8px;
          padding-inline-end: 12px;
          white-space: nowrap;
        }
        #leftContent { flex: 0 1 0; position: relative; transition: opacity 100ms; }
        #leftSpacer {
          align-items: center;
          box-sizing: border-box;
          display: flex;
          padding-inline-start: var(--settings-toolbar-padding-inline-start);
          width: var(--settings-menu-width);
        }
        #menuButton {
          --cr-icon-button-fill-color: currentColor;
          --cr-icon-button-size: 32px;
          min-width: 32px;
        }
        #centeredContent {
          display: flex;
          flex: 1 1 0;
          flex-basis: var(--settings-main-basis);
          justify-content: center;
        }
        :host([showing-search][is-search-box-cutoff]) os-settings-search-box {
          --cr-toolbar-field-width: min(80vw, var(--settings-toolbar-search-box-width));
          margin-inline-start: 48px;
        }
        :host([narrow]) #leftSpacer {
          padding-inline-start: var(--settings-toolbar-padding-inline-start-narrow);
          width: 20px;
        }
        :host([narrow]) #centeredContent { position: absolute; width: 100%; z-index: -1; }
        :host([narrow]:not([showing-search])) #centeredContent { justify-content: flex-end; }
        :host([narrow][showing-search]) h1 { display: none; }
        :host([showing-search][is-search-box-cutoff][narrow]) os-settings-search-box {
          --cr-toolbar-field-width: min(80vw, var(--settings-toolbar-narrow-search-box-width));
        }
        :host([showing-search][narrow]:not([is-search-box-cutoff])) os-settings-search-box {
          --cr-toolbar-field-width: var(--settings-toolbar-narrow-search-box-width);
        }
        :host(:not([narrow]):not([is-search-box-cutoff])) os-settings-search-box {
          --cr-toolbar-field-width: var(--settings-toolbar-search-box-width);
        }
      </style>
      <iron-media-query query="(max-width: 780px)"
          query-matches="{{isSearchBoxCutoff}}"></iron-media-query>
      <div id="leftContent">
        <div id="leftSpacer">
          <template is="dom-if" if="[[narrow]]">
            <cr-icon-button id="menuButton" class="no-overlap" iron-icon="cr20:menu"
                on-click="_menu" aria-label="Menu" title="Menu"></cr-icon-button>
          </template>
          <h1>Modmium</h1>
        </div>
      </div>
      <div id="centeredContent">
        <os-settings-search-box id="searchBox" narrow="[[narrow]]"
            query="[[query]]" results="[[results]]"
            showing-search="{{showingSearch}}">
        </os-settings-search-box>
      </div>
    `;
  }
  _menu() { this.dispatchEvent(new CustomEvent('modmium-menu', {bubbles: true, composed: true})); }
}
customElements.define(SettingsToolbarElement.is, SettingsToolbarElement);

class ModmiumSettingsMainElement extends PolymerElement {
  static get is() { return 'modmium-settings-main'; }
  static get properties() {
    return {
      page: String,
      detail: String,
      daemonStatus: String,
      moshMenus: Object,
      cards: {type: Array, computed: '_cards(page, detail, daemonStatus, moshMenus)'},
      title: {type: String, computed: '_title(detail)'},
    };
  }
  static get observers() { return ['_routeChanged(page, detail)']; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides cr-icons">
        :host {
          align-items: center;
          box-sizing: border-box;
          display: flex;
          flex-direction: column;
          padding: 0 16px 16px;
        }
        #mainPageContainer {
          --page-backdrop-bg-color: var(--cros-sys-surface1);
          background-color: var(--page-backdrop-bg-color);
          border-radius: 20px;
          box-sizing: border-box;
          flex: 1;
          max-width: 958px;
          min-height: 100%;
          min-width: 640px;
          padding: 8px 16px 16px;
          position: relative;
          width: 100%;
        }
        #mainPageContainer.entering {
          animation: settings-page-enter 120ms cubic-bezier(.2, 0, 0, 1);
        }
        @keyframes settings-page-enter {
          from { opacity: 0; transform: translateY(4px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @media (prefers-color-scheme: dark) {
          #mainPageContainer { --page-backdrop-bg-color: var(--cros-sys-app_base); }
        }
        #subpageHeader {
          align-items: center;
          display: flex;
          min-height: 40px;
          padding: 16px 0;
        }
        #subpageHeader[hidden] { display: none; }
        #subpageTitle {
          color: var(--cros-sys-primary);
          flex: 1;
          font: var(--cros-button-1-font);
          margin: 0;
        }
        #backButton {
          --cr-icon-button-fill-color: var(--cros-sys-primary);
          margin-inline-end: 10px;
          margin-inline-start: -10px;
        }
        @media (max-width: 680px) {
          #mainPageContainer { min-width: 0; }
          :host { padding-inline: 3px; }
        }
        @media (prefers-reduced-motion: reduce) {
          #mainPageContainer.entering { animation: none; }
        }
      </style>
      <div id="mainPageContainer">
        <div id="subpageHeader" class="cr-row first" hidden$="[[!detail]]">
          <cr-icon-button id="backButton" class="icon-arrow-back"
              iron-icon="cr:arrow-back" on-click="_back"
              aria-label="Back">
          </cr-icon-button>
          <h1 id="subpageTitle">[[title]]</h1>
        </div>
        <template is="dom-repeat" items="[[cards]]" as="card">
          <settings-card header-text="[[card.header]]">
            <template is="dom-repeat" items="[[card.rows]]" as="row">
              <modmium-settings-row item="[[row]]"></modmium-settings-row>
            </template>
          </settings-card>
        </template>
      </div>
    `;
  }
  _cards(page, detail, daemonStatus, moshMenus) {
    const source = detail ? DETAIL_DATA[detail]?.cards :
      GUI_PAGE_OVERRIDES[page] || genericMenuCards(moshMenus?.[page]);
    const cards = structuredClone(source || GUI_PAGE_OVERRIDES.manager);
    for (const card of cards) {
      for (const row of card.rows) {
        if (row.status) row.sublabel = daemonStatus;
        if (row.detail && !row.action) row.action = 'Open';
      }
    }
    return cards;
  }
  _title(detail) { return DETAIL_DATA[detail]?.title || ''; }
  _routeChanged() {
    if (!this.$?.mainPageContainer) return;
    this.$.mainPageContainer.classList.remove('entering');
    requestAnimationFrame(() => this.$.mainPageContainer.classList.add('entering'));
  }
  _back() { this.dispatchEvent(new CustomEvent('modmium-back', {bubbles: true, composed: true})); }
}
customElements.define(ModmiumSettingsMainElement.is, ModmiumSettingsMainElement);

class ModmiumSettingsUiElement extends PolymerElement {
  static get is() { return 'modmium-settings-ui'; }
  static get properties() {
    return {
      page: {type: String, value: 'manager'},
      detail: {type: String, value: ''},
      daemonStatus: {type: String, value: 'Connecting to Modmium'},
      moshMenus: {type: Object, value: () => ({})},
      isNarrow: {type: Boolean, value: false},
      query: {type: String, value: ''},
      searchResults: {type: Array, value: () => []},
      pendingAction: Object,
      toastText: String,
    };
  }
  static get template() {
    return html`
      <style include="cr-page-host-style cr-shared-style cros-color-overrides cr-icons">
        :host { display: flex; flex-direction: column; height: 100%; }
        :host {
          --settings-main-basis: calc(var(--cr-centered-card-max-width) / .96);
          --cr-card-border-radius: 4px;
          --cr-card-shadow: var(--cr-elevation-1);
          --cr-toolbar-padding-top: 8px;
        }
        #container {
          align-items: flex-start;
          display: flex;
          flex: 1;
          overflow: overlay;
          position: relative;
        }
        #left, #center { flex: 1 1 0; }
        #left {
          flex-grow: 0;
          height: 100%;
          position: sticky;
          top: 0;
          z-index: 100;
        }
        #left os-settings-menu { height: 100%; overflow: auto; overscroll-behavior: contain; }
        #center {
          box-sizing: border-box;
          flex-basis: var(--settings-main-basis);
          height: 100%;
          padding-top: 8px;
        }
        #center > modmium-settings-main { min-height: 100%; }
        #drawer {
          --cr-drawer-border-start-end-radius: 12px;
          --cr-drawer-border-end-end-radius: 12px;
          --cr-drawer-header-color: var(--cros-sys-primary);
          --cr-drawer-header-font: var(--cros-title-1-font);
          --cr-drawer-header-padding: 22px;
          --cr-drawer-width: var(--settings-menu-width);
          --cr-separator-line: none;
        }
        #drawerIcon {
          --iron-icon-fill-color: var(--cros-sys-primary);
          margin-inline-end: 6px;
          margin-inline-start: 0;
        }
        cr-toast { left: 50%; transform: translateX(-50%); }
        @media (max-width: 980px) {
          #left { display: none; }
          #center { min-width: auto; padding: 0 3px; }
        }
      </style>

      <modmium-icons></modmium-icons>
      <iron-media-query query="(max-width: 980px)"
          query-matches="{{isNarrow}}"></iron-media-query>
      <settings-toolbar query="[[query]]" results="[[searchResults]]" narrow="[[isNarrow]]"
          on-modmium-menu="_toggleMenu"
          on-modmium-search="_search"
          on-modmium-search-select="_searchSelect">
      </settings-toolbar>

      <cr-drawer id="drawer" heading="Modmium" align="left">
        <div slot="header-icon">
          <cr-icon-button id="drawerIcon" iron-icon="cr20:menu"
              on-click="_closeMenu" title="Close"></cr-icon-button>
        </div>
        <div slot="body">
          <os-settings-menu selected-path="[[page]]"
              on-modmium-navigate="_navigatePage"></os-settings-menu>
        </div>
      </cr-drawer>

      <div id="container">
        <div id="left">
          <os-settings-menu selected-path="[[page]]" on-modmium-navigate="_navigatePage">
          </os-settings-menu>
        </div>
        <div id="center">
          <modmium-settings-main page="[[page]]" detail="[[detail]]"
              daemon-status="[[daemonStatus]]"
              mosh-menus="[[moshMenus]]"
              on-modmium-open-detail="_openDetail"
              on-modmium-action="_action"
              on-modmium-back="_back">
          </modmium-settings-main>
        </div>
      </div>

      <cr-toast id="toast" duration="2500"><span>[[toastText]]</span></cr-toast>
      <iframe id="daemonBridge" hidden src="http://127.0.0.1:27182/bridge"
          title="Modmium service"></iframe>
      <cr-dialog id="confirmDialog">
        <div slot="title">Confirm action</div>
        <div slot="body">[[pendingAction.message]]</div>
        <div slot="button-container">
          <cr-button class="cancel-button" on-click="_cancelAction">Cancel</cr-button>
          <cr-button class="action-button" on-click="_confirmAction">Continue</cr-button>
        </div>
      </cr-dialog>
    `;
  }
  connectedCallback() {
    super.connectedCallback();
    window.addEventListener('popstate', () => this._readRoute());
    this._daemonMessage = event => this._handleDaemonMessage(event);
    window.addEventListener('message', this._daemonMessage);
    this._readRoute();
    this._connectDaemon();
    document.documentElement.classList.remove('loading');
  }
  disconnectedCallback() {
    super.disconnectedCallback();
    window.removeEventListener('message', this._daemonMessage);
    clearTimeout(this._daemonTimer);
  }
  _readRoute() {
    const [page = 'manager', detail = ''] = location.hash.replace(/^#\/?/, '').split('/');
    if (DETAIL_DATA[detail]) {
      this.page = DETAIL_DATA[detail].page;
      this.detail = detail;
    } else {
      this.page = (GUI_PAGE_OVERRIDES[page] || this.moshMenus[page]) ? page : 'manager';
      this.detail = '';
    }
  }
  _setRoute(page, detail = '') {
    const hash = `#/${page}${detail ? `/${detail}` : ''}`;
    if (location.hash === hash) return;
    history.pushState({}, '', hash);
    this.page = page;
    this.detail = detail;
    this.query = '';
    this.searchResults = [];
    this.$.container.scrollTo({top: 0, behavior: 'auto'});
  }
  _navigatePage(event) {
    this._setRoute(event.detail);
    if (this.isNarrow) this.$.drawer.close();
  }
  _openDetail(event) { this._setRoute(this.page, event.detail); }
  _back() {
    if (this.detail) history.back();
  }
  _toggleMenu() { this.$.drawer.openDrawer(); }
  _closeMenu() { this.$.drawer.close(); }
  _search(event) {
    this.query = event.detail.trim();
    const query = this.query.toLocaleLowerCase();
    this.searchResults = query ? SEARCH_ENTRIES.filter(entry =>
      entry.label.toLocaleLowerCase().includes(query)).slice(0, 6) : [];
  }
  _searchSelect(event) {
    const entry = event.detail;
    this._setRoute(entry.page, entry.detail);
  }
  _action(event) {
    const action = event.detail;
    if (action.danger) {
      this.pendingAction = {
        ...action,
        successMessage: action.message,
        message: action.prompt || action.message,
      };
      this.$.confirmDialog.showModal();
      return;
    }
    this._runAction(action);
  }
  _cancelAction() {
    this.$.confirmDialog.cancel();
    this.pendingAction = null;
  }
  _confirmAction() {
    const action = this.pendingAction;
    this.$.confirmDialog.close();
    this.pendingAction = null;
    this._runAction(action);
  }
  _runAction(action) {
    if (!action.moshAction) {
      this._showToast(action.message);
      return;
    }
    const fields = ['run', action.moshAction, ...(action.args || [])]
      .map(field => encodeURIComponent(String(field)));
    this._pendingMoshAction = action;
    this.$.daemonBridge.contentWindow.postMessage({
      type: 'request', body: fields.join('\t'),
    }, 'http://127.0.0.1:27182');
    this._showToast('Working…');
  }
  _showToast(message) {
    this.toastText = message;
    this.$.toast.show();
  }
  _connectDaemon() {
    this._daemonTimer = setTimeout(() => {
      if (this.daemonStatus === 'Connecting to Modmium') {
        this.daemonStatus = 'Service unavailable';
      }
    }, 3000);
  }
  _handleDaemonMessage(event) {
    if (event.origin !== 'http://127.0.0.1:27182' ||
        event.source !== this.$.daemonBridge.contentWindow) {
      return;
    }
    if (event.data?.type === 'ready') {
      event.source.postMessage({type: 'request', body: 'health'}, event.origin);
      event.source.postMessage({type: 'request', body: 'menus'}, event.origin);
      return;
    }
    if (event.data?.type !== 'response' || typeof event.data.body !== 'string') return;

    clearTimeout(this._daemonTimer);
    try {
      const response = JSON.parse(event.data.body);
      if (response.status) {
        this.daemonStatus = response.status === 'ok' ?
          `Service ${response.serviceVersion}` : 'Service error';
      } else if (response.type === 'menus') {
        this.moshMenus = Object.fromEntries(response.menus.map(menu => [menu.id, menu]));
      } else if (response.type === 'action' && response.ok) {
        this._showToast(this._pendingMoshAction?.successMessage ||
          this._pendingMoshAction?.message || 'Done');
        this._pendingMoshAction = null;
      } else if (response.error) {
        this._showToast(response.error);
        this._pendingMoshAction = null;
      }
    } catch {
      this.daemonStatus = 'Service error';
    }
  }
}
customElements.define(ModmiumSettingsUiElement.is, ModmiumSettingsUiElement);

window.addEventListener('load', () => {
  ColorChangeUpdater.forDocument().start();
});
