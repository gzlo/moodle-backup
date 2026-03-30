FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash \
    mysql-client \
    php-cli \
    tar \
    gzip \
    zip \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install BATS
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats && \
    cd /tmp/bats && ./install.sh /usr/local && rm -rf /tmp/bats

# Install rclone (for integration tests)
RUN curl -fsSL https://rclone.org/install.sh | bash || true

# Create fake Moodle structure
RUN mkdir -p /var/www/moodle/admin/cli && \
    echo '<?php echo "OK";' > /var/www/moodle/admin/cli/maintenance.php && \
    mkdir -p /var/moodledata && \
    echo "test" > /var/moodledata/testfile.txt

WORKDIR /opt/moodle-backup

CMD ["bash", "-c", "echo '=== Docker Test Suite ===' && bats tests/unit/ && echo '✅ All tests passed'"]
