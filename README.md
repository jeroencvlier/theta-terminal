# Theta Terminal Docker

This repository contains the Docker configuration for running Theta Terminal.

## Prerequisites

- Docker
- Docker Compose
- Make (optional, for using Makefile commands)

## Setup

1. Clone this repository
2. Create a `.env` file in the root directory with your credentials:
```env
THETADATAUSERNAME=your_username
THETADATAPASSWORD=your_password
THETATERMINALID=your_terminal_id
```

## Configuration Files

Place your configuration files in the `configs/` directory. These will be automatically copied into the container at `/root/ThetaData/ThetaTerminal/`.

## Usage

This project includes a Makefile for common operations. You can use the following commands:

```bash
make help     # Show available commands
make build    # Build the Docker image
make up       # Start the container
make down     # Stop the container
make logs     # View container logs
make restart  # Restart the container
make clean    # Remove all containers and images
make start    # Build, start and show logs
```

## Directory Structure

```
.
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── README.md
├── .env
└── configs/
    ├── config_0.properties
    └── config_1.properties
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| THETADATAUSERNAME | Your Theta Data username |
| THETADATAPASSWORD | Your Theta Data password |
| THETATERMINALID | Terminal ID (0 = Deployment, 1 = Development) |

## Troubleshooting

If you encounter issues:
1. Check your environment variables in the `.env` file
2. Ensure all configuration files are present in the `configs/` directory
3. View logs using `make logs` to identify any startup issues
