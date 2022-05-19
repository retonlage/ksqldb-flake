{
  description = "ksqlDB is a database purpose-built for stream processing applications";

  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, utils }:
  utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages."${system}";
  in rec {
    packages = {
      ksqldb-bin = pkgs.fetchzip {
        name = "ksqldb";
        url = "http://ksqldb-packages.s3.amazonaws.com/archive/0.26/confluent-ksqldb-0.26.0.tar.gz";
        sha256 = "sha256-FmITqBncveb12PfLuCKhgAzvnL1GHRKsLGRBwSTSR+4=";
      };
    };
    nixosModule = nixosModules.ksqldb;
    nixosModules = {
      ksqldb = {config, ...}: {
        options = {
          services.ksqldb.enable = pkgs.lib.mkOption {
            description = "Whether to enable ksqlDB";
            default = false;
            type = pkgs.lib.types.bool;
          };

          services.ksqldb.package = pkgs.lib.mkOption {
            description = "The ksqlDB package to use";
            default = packages.ksqldb-bin;
            type = pkgs.lib.types.package;
          };

          services.ksqldb.bootstrap-servers = pkgs.lib.mkOption {
            description = "The set of Kafka brokers to bootstrap Kafka cluster information from";
            default = "localhost:9092";
            type = pkgs.lib.types.str;
          };
        };
        config =
          let
            cfg = config.services.ksqldb;
            server-properties = pkgs.writeText "ksql-server.properties"
            ''
            bootstrap.servers=${cfg.bootstrap-servers}
            '';
          in pkgs.lib.mkIf cfg.enable {
            systemd.services = {
              ksqldb = {
                description = "Streaming SQL engine for Apache Kafka";
                documentation = "http://docs.confluent.io/";
                after = ["network.target" "confluent-kafka.target confluent-schema-registry.target"];
                wantedBy = ["multi-user.target"];
                script = "${cfg.package}/bin/ksql-server-start";
                scriptArgs = "${server-properties}";
                serviceConfig = {
                  Type = "simple";
                  User = "cp-ksql";
                  Group = "confluent";
                  Environment = "LOG_DIR=/var/log/confluent/ksql";
                  TimeoutStopSec = "180";
                  Restart = "no";
                };
              };
            };
            environment.systemPackages = [cfg.package];
            services.apache-kafka.enable = true;
          };
        };
      };
    });
  }
