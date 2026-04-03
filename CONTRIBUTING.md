# Contributing to Customer Order Services Jakarta EE

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Code of Conduct

Be respectful, constructive, and collaborative. This is a learning and reference project.

## How to Contribute

### Reporting Issues

When reporting issues, include:
- **Environment:** OS, Java version, application server version
- **Steps to reproduce:** Clear, numbered steps
- **Expected vs. actual behavior**
- **Logs:** Relevant error messages or stack traces
- **Screenshots:** If applicable

### Suggesting Enhancements

For enhancement suggestions:
- Check existing issues first
- Describe the current limitation
- Explain the proposed solution
- Discuss potential impacts

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes:**
   - Follow existing code style
   - Add tests for new functionality
   - Update documentation
4. **Test thoroughly:**
   ```bash
   mvn clean verify
   ```
5. **Commit with clear messages:**
   ```bash
   git commit -m "Add feature: brief description
   
   Longer description of what changed and why.
   
   Fixes #123"
   ```
6. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Create Pull Request** on GitHub

## Development Setup

### Prerequisites

- Java 11 or later
- Maven 3.6+
- Podman or Docker
- Git

### Local Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/refarch-jee-jakarta.git
cd refarch-jee-jakarta

# Add upstream remote
git remote add upstream https://github.com/dandesilva/refarch-jee-jakarta.git

# Start development database
podman network create customerorder-net
podman run -d --name postgres-orderdb \
  --network customerorder-net \
  -p 15432:5432 \
  -e POSTGRES_DB=ORDERDB \
  -e POSTGRES_USER=db2inst1 \
  -e POSTGRES_PASSWORD=db2inst1 \
  postgres:15

# Load schema
podman exec -i postgres-orderdb \
  psql -U db2inst1 -d ORDERDB < Common/createOrderDB_postgres.sql

# Build project
cd CustomerOrderServicesProject
mvn clean package

# Run tests
mvn test
```

## Code Style

### Java

- **Indentation:** 4 spaces (no tabs)
- **Line length:** 120 characters max
- **Braces:** Required even for single-line blocks
- **Naming:**
  - Classes: `PascalCase`
  - Methods/variables: `camelCase`
  - Constants: `UPPER_SNAKE_CASE`

Example:
```java
public class ProductService {
    private static final int MAX_RESULTS = 100;
    
    public Product findProduct(int productId) {
        if (productId <= 0) {
            throw new IllegalArgumentException("Invalid product ID");
        }
        return repository.find(productId);
    }
}
```

### XML

- **Indentation:** 2 spaces
- **Attributes:** Double quotes
- **Order:** Alphabetical when possible

### Documentation

- **JavaDoc:** Required for public APIs
- **Comments:** Explain "why", not "what"
- **Markdown:** For all documentation files

## Testing

### Unit Tests

```bash
mvn test
```

### Integration Tests

```bash
mvn verify -P integration-tests
```

### Manual Testing

```bash
# Build and run
podman build -f Dockerfile.redhat -t customerorder-app:test .
podman run -d --name test-app --network customerorder-net \
  -p 8080:8080 customerorder-app:test

# Test endpoints
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category
```

## Documentation

When adding features, update:
- [ ] README.md (if it affects setup or usage)
- [ ] MIGRATION.md (if it's migration-related)
- [ ] DEPLOYMENT.md (if it affects deployment)
- [ ] JavaDoc (for new public APIs)
- [ ] Code comments (for complex logic)

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, etc.

**Examples:**
```
feat(api): add pagination to product search

Implements offset/limit parameters for product queries.
Returns total count in response headers.

Closes #45
```

```
fix(ejb): resolve null pointer in customer service

Adds null check before accessing customer address.
Improves error handling for missing customer data.

Fixes #67
```

## Pull Request Process

1. **Update documentation** as needed
2. **Add tests** for new functionality
3. **Ensure all tests pass**
4. **Update CHANGELOG.md** (if applicable)
5. **Request review** from maintainers
6. **Address feedback** promptly
7. **Squash commits** if requested
8. **Wait for approval** before merging

## Review Criteria

Pull requests will be reviewed for:
- **Functionality:** Does it work as intended?
- **Code quality:** Is it well-structured and readable?
- **Tests:** Are there adequate tests?
- **Documentation:** Is it properly documented?
- **Compatibility:** Does it maintain backward compatibility?
- **Security:** Are there any security concerns?

## Areas for Contribution

### High Priority

- [ ] Re-enable and update test module
- [ ] Add integration tests
- [ ] Implement proper security/authentication
- [ ] Add OpenAPI/Swagger documentation
- [ ] Performance benchmarks

### Medium Priority

- [ ] Add caching layer
- [ ] Implement search functionality
- [ ] Add product images support
- [ ] Create admin UI
- [ ] Add monitoring/metrics

### Low Priority

- [ ] Additional database support (MySQL, Oracle)
- [ ] GraphQL API
- [ ] WebSocket notifications
- [ ] Mobile app integration
- [ ] Microservices refactoring

## Resources

- [Jakarta EE Specifications](https://jakarta.ee/specifications/)
- [WildFly Documentation](https://docs.wildfly.org/)
- [Hibernate Documentation](https://hibernate.org/orm/documentation/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## Questions?

- Open an issue for discussion
- Check existing issues and pull requests
- Review the [session logs](docs/session-logs/) for detailed examples

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

---

Thank you for contributing to Customer Order Services Jakarta EE! 🚀
