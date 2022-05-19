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
        extraPostFetch =
        let bashScripts = [
          "bin/ksql-print-metrics"
          "bin/ksql"
          "bin/ksql-server-start"
          "bin/ksql-datagen"
          "bin/ksql-migrations"
          "bin/ksql-stop"
          "bin/ksql-restore-command-topic"
          "bin/ksql-test-runner"
          "bin/ksql-server-stop"
          "bin/ksql-run-class"
        ];
        in
        pkgs.lib.strings.concatStrings (builtins.map (bashScript: "substituteInPlace $out/${bashScript} --replace '#!/bin/bash' '${pkgs.bash}/bin/bash';") bashScripts);
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
                documentation = ["http://docs.confluent.io/"];
                after = ["network.target" "confluent-kafka.target confluent-schema-registry.target"];
                wantedBy = ["multi-user.target"];
                script = "${pkgs.bash}/bin/bash ${cfg.package}/bin/ksql-server-start ${server-properties}";
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
