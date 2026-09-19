<!--
  Copyright (C) 2022 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <cv-text-input
              :label="$t('settings.freeradius_fqdn')"
              placeholder="freeradius.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="host"
            >
            </cv-text-input>
            <cv-toggle
              value="letsEncrypt"
              :label="$t('settings.lets_encrypt')"
              v-model="isLetsEncryptEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <cv-toggle
              value="httpToHttps"
              :label="$t('settings.http_to_https')"
              v-model="isHttpToHttpsEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <NsComboBox
              v-model.trim="ldapDomain"
              :autoFilter="true"
              :autoHighlight="true"
              :title="$t('settings.ldap_domain')"
              :label="$t('settings.choose_ldap_domain')"
              :options="domainOptions"
              :acceptUserInput="false"
              :showItemType="true"
              :invalid-message="$t(error.ldap_domain)"
              :disabled="
                loading.getConfiguration ||
                loading.configureModule ||
                loading.listUserDomains
              "
              tooltipAlignment="start"
              tooltipDirection="top"
              class="mg-bottom"
              ref="ldap_domain"
            >
              <template slot="tooltip">
                {{ $t("settings.ldap_domain_tooltip") }}
              </template>
            </NsComboBox>
            <h4 class="mg-bottom-sm">{{ $t("settings.clients") }}</h4>
            <p class="mg-bottom-sm clients-help">
              {{ $t("settings.clients_description") }}
            </p>
            <NsInlineNotification
              v-if="error.clients"
              kind="error"
              :title="$t('settings.clients')"
              :description="error.clients"
              :showCloseButton="false"
            />
            <div
              v-for="(client, index) in clients"
              :key="index"
              class="client-row"
            >
              <NsTextInput
                :label="$t('settings.client_name')"
                v-model.trim="client.name"
                placeholder="ap-office"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="client-field"
              />
              <NsTextInput
                :label="$t('settings.client_ipaddr')"
                v-model.trim="client.ipaddr"
                placeholder="192.168.1.10"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="client-field"
              />
              <NsPasswordInput
                :newPasswordLabel="$t('settings.client_secret')"
                v-model="client.secret"
                :showPasswordLabel="$t('settings.show_secret')"
                :hidePasswordLabel="$t('settings.hide_secret')"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="client-field"
              />
              <div class="client-actions">
                <NsButton
                  kind="ghost"
                  size="field"
                  type="button"
                  :disabled="
                    loading.getConfiguration || loading.configureModule
                  "
                  @click="generateSecret(index)"
                  >{{ $t("settings.generate_secret") }}</NsButton
                >
                <NsButton
                  kind="danger--ghost"
                  size="field"
                  type="button"
                  :icon="TrashCan20"
                  :disabled="
                    loading.getConfiguration || loading.configureModule
                  "
                  @click="removeClient(index)"
                  >{{ $t("settings.remove_client") }}</NsButton
                >
              </div>
            </div>
            <NsButton
              kind="secondary"
              type="button"
              :icon="Add20"
              :disabled="loading.getConfiguration || loading.configureModule"
              @click="addClient"
              class="mg-bottom"
              >{{ $t("settings.add_client") }}</NsButton
            >
            <!-- advanced options -->
            <cv-accordion ref="accordion" class="maxwidth mg-bottom">
              <cv-accordion-item :open="toggleAccordion[0]">
                <template slot="title">{{ $t("settings.advanced") }}</template>
                <template slot="content"> </template>
              </cv-accordion-item>
            </cv-accordion>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      urlCheckInterval: null,
      host: "",
      isLetsEncryptEnabled: false,
      isHttpToHttpsEnabled: true,
      ldapDomain: "",
      domainOptions: [],
      clients: [],
      loading: {
        getConfiguration: false,
        configureModule: false,
        listUserDomains: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        host: "",
        lets_encrypt: "",
        http2https: "",
        ldap_domain: "",
        clients: "",
        listUserDomains: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
  },
  created() {
    this.getConfiguration();
    this.listUserDomains();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isHttpToHttpsEnabled = config.http2https;

      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);

      let isValidationOk = true;
      if (!this.host) {
        this.error.host = "common.required";

        if (isValidationOk) {
          this.focusElement("host");
        }
        isValidationOk = false;
      }
      const names = new Set();
      for (const client of this.clients) {
        const name = (client.name || "").toLowerCase();
        if (
          !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$/.test(client.name || "") ||
          names.has(name)
        ) {
          this.error.clients = this.$t("settings.client_name_invalid");
          isValidationOk = false;
        } else if (!client.ipaddr) {
          this.error.clients = this.$t("settings.client_ipaddr_invalid");
          isValidationOk = false;
        } else if (
          !/^[\x20-\x21\x23-\x5b\x5d-\x7e]{8,128}$/.test(client.secret || "")
        ) {
          this.error.clients = this.$t("settings.client_secret_invalid");
          isValidationOk = false;
        }
        names.add(name);
      }
      return isValidationOk;
    },
    addClient() {
      this.clients.push({ name: "", ipaddr: "", secret: "" });
      this.generateSecret(this.clients.length - 1);
    },
    removeClient(index) {
      this.clients.splice(index, 1);
    },
    generateSecret(index) {
      const alphabet =
        "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
      const random = new Uint32Array(32);
      window.crypto.getRandomValues(random);
      let secret = "";
      for (const value of random) {
        secret += alphabet[value % alphabet.length];
      }
      this.$set(this.clients[index], "secret", secret);
    },
    async listUserDomains() {
      this.loading.listUserDomains = true;
      this.error.listUserDomains = "";
      const taskAction = "list-user-domains";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.listUserDomainsAborted
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.listUserDomainsCompleted
      );
      const res = await to(
        this.createClusterTaskForApp({
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.listUserDomains = this.getErrorMessage(err);
        this.loading.listUserDomains = false;
      }
    },
    listUserDomainsAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.listUserDomains = this.$t("error.generic_error");
      this.loading.listUserDomains = false;
    },
    listUserDomainsCompleted(taskContext, taskResult) {
      const options = [
        { name: "-", label: this.$t("settings.no_ldap_domain"), value: "" },
      ];
      for (const domain of taskResult.output.domains) {
        options.push({
          name: domain.name,
          label: domain.name,
          value: domain.name,
          type: domain.schema,
        });
      }
      this.domainOptions = options;
      this.loading.listUserDomains = false;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        // set i18n error message
        if (param == "clients") {
          this.error.clients =
            this.$t("settings." + validationError.error) +
            (validationError.value ? ": " + validationError.value : "");
          continue;
        }
        this.error[param] = this.$t("settings." + validationError.error);

        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
        }
      }
    },
    async configureModule() {
      this.error.test_imap = false;
      this.error.test_smtp = false;
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            http2https: this.isHttpToHttpsEnabled,
            ldap_domain: this.ldapDomain,
            clients: this.clients,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.mg-bottom-sm {
  margin-bottom: $spacing-03;
}

.maxwidth {
  max-width: 38rem;
}

.clients-help {
  max-width: 38rem;
}

.client-row {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: $spacing-05;
  margin-bottom: $spacing-06;
}

.client-field {
  flex: 1 1 12rem;
  max-width: 20rem;
}

.client-actions {
  display: flex;
  gap: $spacing-03;
}
</style>
