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
    nixosModules = {
      ksqldb = {config}: {
        options = {
          services.ksqldb.enable = pkgs.mkOption {
            description = "Whether to enable ksqlDB";
            default = false;
            type = pkgs.types.bool;
          };

          services.ksqldb.package = pkgs.mkOption {
            description = "The ksqlDB package to use";
            default = packages.ksqldb-bin;
            type = pkgs.types.package;
          };

          services.ksqldb.bootstrap-servers = pkgs.mkOption {
            description = "The set of Kafka brokers to bootstrap Kafka cluster information from";
            default = "localhost:9092";
            type = pkgs.types.str;
          };
        };
        config =
          let
            cfg = config.services.ksqldb;
            server-properties = pkgs.writeText "ksql-server.properties"
            ''
            bootstrap.servers=${cfg.bootstrap-servers}
            '';
          in pkgs.mkIf cfg.enable {
            systemd.services = {
              ksqldb = {
                description = "Streaming SQL engine for Apache Kafka";
                documentation = "http://docs.confluent.io/";
                after = ["network.target" "confluent-kafka.target confluent-schema-registry.target"];
                wantedBy = ["multi-user.target"];
                script = "${cfg.package}/bin/ksql-server-start";
                scriptArgs = ["${server-properties}"];
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
