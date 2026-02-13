# Contributing to Asterisk USB/IP Dongle System

Thank you for considering contributing to this project! This document provides guidelines and instructions for contributing.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of experience level, background, or identity.

### Our Standards

**Examples of positive behavior:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior:**
- Harassment, trolling, or discriminatory comments
- Publishing others' private information without permission
- Other conduct which could reasonably be considered inappropriate

## How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**When submitting a bug report, include:**
- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Environment details:**
  - OS and version
  - Docker version
  - Asterisk version (from container logs)
  - USB/IP version
- **Logs:**
  ```bash
  docker-compose logs
  sudo journalctl -u usbip-huawei-monitor.service
  ```
- **Configuration** (sanitize sensitive information!)

**Bug Report Template:**
```markdown
### Description
Brief description of the issue

### Steps to Reproduce
1. 
2. 
3. 

### Expected Behavior
What should happen

### Actual Behavior
What actually happens

### Environment
- OS: 
- Docker version: 
- Asterisk version: 

### Logs
```
Paste relevant logs here
```

### Additional Context
Any other relevant information
```

### 💡 Suggesting Enhancements

Enhancement suggestions are welcome! Please include:
- **Clear use case:** Why is this enhancement needed?
- **Proposed solution:** How would it work?
- **Alternatives considered:** What other approaches did you consider?
- **Additional context:** Screenshots, examples, etc.

### 🔧 Code Contributions

We welcome code contributions! Areas that especially need help:
- **Testing:** Additional test cases and validation scripts
- **Documentation:** Improvements, translations, examples
- **Platform support:** Testing on different distributions
- **Security:** Security audits and improvements
- **Features:** New functionality that aligns with project goals

## Development Setup

### Prerequisites

- Linux development environment (Ubuntu/Debian recommended)
- Docker and Docker Compose
- Git
- Text editor or IDE
- USB/IP tools for testing

### Setting Up Development Environment

1. **Fork the repository** on GitHub

2. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/asterisk-usbip-dongle.git
   cd asterisk-usbip-dongle
   ```

3. **Add upstream remote:**
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/asterisk-usbip-dongle.git
   ```

4. **Create a development branch:**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bugfix-name
   ```

5. **Set up test environment:**
   ```bash
   cp env.sh env.sh.example
   # Edit env.sh with your test values
   nano env.sh
   ```

### Testing Your Changes

#### For Asterisk Container Changes

```bash
# Build with your changes
docker-compose build --no-cache

# Start and test
docker-compose up -d
docker-compose logs -f

# Test Asterisk functionality
docker exec -it asterisk-dongle asterisk -rvvv
```

#### For USB/IP Server Changes

```bash
# Test on a development system (not production!)
cd dongleserver
sudo ./install.sh

# Monitor logs
sudo journalctl -u usbip-huawei-monitor.service -f

# Validate
sudo ./validate.sh
```

## Coding Standards

### Shell Scripts

- **Shebang:** Use `#!/bin/bash` for Bash scripts, `#!/bin/sh` for POSIX scripts
- **Error handling:** Use `set -e` for critical scripts
- **Variables:** 
  - Use `UPPER_CASE` for environment variables
  - Use `lower_case` for local variables
- **Functions:** Use descriptive names with verbs
- **Comments:** Document complex logic and non-obvious behavior

**Example:**
```bash
#!/bin/bash
set -e

# Function to bind USB device
bind_device() {
    local busid="$1"
    local device_name="$2"
    
    if usbip bind -b "$busid"; then
        echo "Successfully bound device: $device_name ($busid)"
        return 0
    else
        echo "ERROR: Failed to bind device: $device_name ($busid)"
        return 1
    fi
}
```

### Dockerfile

- **Base images:** Use official images when possible
- **Layer optimization:** Combine RUN commands to reduce layers
- **Security:** Don't run as root when possible
- **Clean up:** Remove unnecessary files in the same layer

### Docker Compose

- **Version:** Use version 3.x format
- **Comments:** Document non-obvious settings
- **Variables:** Use environment variables for configuration

### Configuration Files

- **Templates:** Use clear variable names with descriptive comments
- **Defaults:** Provide sensible defaults
- **Validation:** Document required vs optional settings

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(dongle): add support for multiple dongle vendors

- Add configuration option for vendor ID
- Update detection script to handle different vendors
- Update documentation with new vendor support

Closes #123
```

```
fix(docker): resolve USB device permission issue

The usbip.sh script now properly sets permissions on all
ttyUSB devices after connection.

Fixes #456
```

### Best Practices

- **Atomic commits:** Each commit should be a single logical change
- **Descriptive messages:** Explain *why*, not just *what*
- **Reference issues:** Use `Fixes #123` or `Closes #456`
- **Sign commits:** Use `-s` flag to sign-off commits

## Pull Request Process

### Before Submitting

- [ ] Test your changes thoroughly
- [ ] Update documentation if needed
- [ ] Add comments to complex code
- [ ] Check that all services start successfully
- [ ] Verify existing functionality still works

### Submitting a PR

1. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request** on GitHub

3. **Fill out the PR template:**
   ```markdown
   ### Description
   Brief description of changes
   
   ### Motivation and Context
   Why is this change needed?
   
   ### Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Refactoring
   
   ### How Has This Been Tested?
   - [ ] Tested on Ubuntu 22.04
   - [ ] Tested with single dongle
   - [ ] Tested with multiple dongles
   - [ ] Tested hot-plug functionality
   
   ### Checklist
   - [ ] My code follows the project's coding standards
   - [ ] I have updated the documentation
   - [ ] My changes generate no new warnings
   - [ ] I have tested my changes
   - [ ] All tests pass
   
   ### Related Issues
   Fixes #123
   Related to #456
   ```

4. **Respond to review feedback** promptly

### Review Process

- Maintainers will review your PR
- Address any requested changes
- Once approved, your PR will be merged

### After Your PR is Merged

- Delete your feature branch
- Update your local repository:
  ```bash
  git checkout main
  git pull upstream main
  ```

## Testing

### Manual Testing Checklist

For Asterisk Container:
- [ ] Container builds without errors
- [ ] Container starts successfully
- [ ] Asterisk CLI is accessible
- [ ] Dongle is detected and initialized
- [ ] Can make outbound call
- [ ] Can send SMS
- [ ] Fail2ban is running
- [ ] USB/IP connection recovers after network interruption

For USB/IP Server:
- [ ] Services install without errors
- [ ] Services start automatically
- [ ] Devices are auto-bound on boot
- [ ] Hot-plug detection works
- [ ] USB reset recovery works
- [ ] Logs are generated correctly

### Automated Testing

We welcome contributions to automated testing! Areas that need test coverage:
- Installation scripts
- Service startup validation
- Configuration file generation
- Error handling

## Documentation

### What to Document

- **New features:** Update README.md with usage instructions
- **Configuration changes:** Update relevant template files and env.sh
- **Bug fixes:** Update CHANGELOG if applicable
- **Installation changes:** Update QUICKSTART.md

### Documentation Style

- Use clear, concise language
- Include examples
- Test all commands and code snippets
- Use proper Markdown formatting
- Include troubleshooting tips

### Files to Update

- `README.md` - Main documentation
- `QUICKSTART.md` - Quick start guide
- `dongleserver/README.md` - USB/IP server docs
- `CHANGELOG.md` - Version history (for releases)
- Inline comments in code

## Questions?

If you have questions about contributing:
- Check existing [Issues](https://github.com/giraygokirmak/asterisk-usbip-dongle/issues)
- Create a new [Discussion](https://github.com/giraygokirmak/asterisk-usbip-dongle/discussions)
- Contact maintainers

## Recognition

Contributors will be recognized in:
- README.md acknowledgments section
- Release notes
- Git commit history

Thank you for contributing! 🎉
