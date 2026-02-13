# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Asterisk USB/IP Dongle System
- Docker-based Asterisk PBX with chan_dongle support
- Automated USB/IP server with hot-plug support and monitoring
- Fail2ban integration for security
- Template-based configuration system
- Comprehensive documentation and quick start guides

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- Fail2ban protection against brute-force attacks
- Configurable firewall rules for USB/IP port

## [1.0.0] - YYYY-MM-DD

### Added
- Complete Asterisk PBX Docker container setup
  - Automatic chan_dongle compilation matching Asterisk version
  - PJSIP support with template-based configuration
  - Fail2ban integration with Asterisk-specific filters
  - Auto-healing USB/IP client connection script
  
- USB/IP Server automated binding system
  - Automatic detection of Huawei modems
  - Boot-time auto-binding service
  - Hot-plug support via udev rules
  - Continuous monitoring with 10-second interval
  - USB reset recovery mechanism
  - Comprehensive logging to systemd journal and file
  
- Documentation suite
  - Main README with architecture overview
  - Quick Start guide for rapid deployment
  - Contributing guidelines
  - Detailed troubleshooting section
  - Security recommendations

- Configuration templates
  - dongle.template for chan_dongle configuration
  - pjsip.template for SIP endpoints
  - extensions.template for dialplan
  - env.sh for environment variables

- Installation scripts
  - docker-compose.yaml for container orchestration
  - install.sh for USB/IP server setup
  - uninstall.sh for clean removal
  - validate.sh for system verification

### Security
- Fail2ban configured for SIP port protection
- 999-hour ban time for repeated attacks
- Network-based access control recommendations
- SSH tunneling documentation for secure remote access

---

## Version History Format

Each version entry should include:
- **Added** - New features
- **Changed** - Changes in existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Now removed features
- **Fixed** - Bug fixes
- **Security** - Security improvements or vulnerability fixes

## Links

- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
