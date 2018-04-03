{%- from 'jira-servicedesk/conf/confluence_settings.sls' import confluence with context %}

confluence:
  group:
    - present
  user.present:
    - fullname: Confluence user
    - shell: /bin/sh
    - home: {{ confluence.home }}
    - groups:
       - confluence

### APPLICATION INSTALL ###
unpack-confluence-tarball:
  archive.extracted:
    - name: {{ confluence.prefix }}
    - source: {{ confluence.source_url }}/{{ confluence.app_name }}-{{ confluence.version }}.tar.gz
    - archive_format: tar
    - skip_verify: true
    - user: confluence
    - options: z
    - if_missing: {{ confluence.prefix }}/atlassian-confluence-{{ confluence.version }}
    - keep: True
    - require:
      - module: confluence-stop
      - file: confluence-init-script
    - listen_in:
      - module: confluence-restart

create-confluence-symlink:
  file.symlink:
    - name: {{ confluence.prefix }}/confluence
    - target: {{ confluence.prefix }}/atlassian-confluence-{{ confluence.version }}
    - user: confluence
    - watch:
      - archive: unpack-confluence-tarball

create-confluence-logs-symlink:
  file.symlink:
    - name: {{ confluence.prefix }}/confluence/logs
    - target: {{ confluence.log_root }}
    - user: confluence
    - backupname: {{ confluence.prefix }}/confluence/old_logs
    - watch:
      - archive: unpack-confluence-tarball

confluence-properties-file:
  file.managed:
    - name: '{{ confluence.prefix }}/confluence/confluence/WEB-INF/classes/confluence-init.properties'
    - source: salt://jira-servicedesk/templates/confluence-init.properties.tmpl
    - user: confluence
    - group: confluence
    - mode: 0755
    - template: jinja
    - context:
      confluence: {{ confluence|json }}


{%if confluence.confluence_cfg_xml is defined %}
{{ confluence.home }}/confluence.cfg.xml:
  file.managed:
    - user: {{ confluence.user }}
    - group: {{ confluence.user }}
    - listen_in:
      - module: confluence-restart
    - contents: {{ confluence.confluence_cfg_xml }}
{% endif %}

{% if confluence.use_https == True %}
confluence-https-replace:
  file.replace:
    - name: {{ confluence.prefix }}/confluence/conf/server.xml
    - pattern:  '\<Connector port=\"8090\"[^\n]*'
    - repl: '<Connector port="8090" connectionTimeout="20000" redirectPort="8443" proxyName="{{ confluence.confluence_hostname }}" proxyPort="443" scheme="https" secure="true"'
{% else %}
confluence-https-replace:
  file.replace:
    - name: {{ confluence.prefix }}/confluence/conf/server.xml
    - pattern:  '\<Connector port="8090"[^\n]+'
    - repl: '<Connector port="8090" connectionTimeout="20000" redirectPort="8443" proxyName="{{ confluence.confluence_hostname }}" proxyPort="80"'
{% endif %}



confluence-unpack-mysql-tarball:
  archive.extracted:
    - name: /tmp/
    - source: {{ confluence.mysql_location }}/mysql-connector-java-{{ confluence.mysql_connector_version }}.tar.gz
    - skip_verify: true
    - archive_format: tar
    - user: confluence
    - options: z
    - if_missing: {{ confluence.prefix }}/confluence/confluence/WEB-INF/lib/mysql-connector-java-{{ confluence.mysql_connector_version }}-bin.jar
    - keep: True

confluence-mysql-jar-copy:
  file.copy:
    - name: {{ confluence.prefix }}/confluence/confluence/WEB-INF/lib/mysql-connector-java-{{ confluence.mysql_connector_version }}-bin.jar
    - source: /tmp/mysql-connector-java-5.1.40/mysql-connector-java-{{ confluence.mysql_connector_version }}-bin.jar
    - user: confluence
    - require:
      - module: confluence-stop
      - file: confluence-init-script
    - listen_in:
      - module: confluence-restart
    - unless:
      - ls {{ confluence.prefix }}/confluence/confluence/WEB-INF/lib/mysql-connector-java-{{ confluence.mysql_connector_version }}-bin.jar

confluence-init-script:
  file.managed:
    - name: '/usr/lib/systemd/system/confluence.service'
    - source: salt://jira-servicedesk/templates/confluence.systemd.tmpl
    - user: root
    - group: root
    - mode: 0755
    - require:
      - file: systemd-system-dir
    - template: jinja
    - context:
      confluence: {{ confluence|json }}

confluence-log-dir:
  file.directory:
    - name: /var/log/confluence
    - user: confluence
    - group: confluence
    - mode: 755
    - makedirs: True

confluence-restart:
  module.wait:
    - name: service.restart
    - m_name: confluence

confluence-stop:
  module.wait:
    - name: service.stop
    - m_name: confluence