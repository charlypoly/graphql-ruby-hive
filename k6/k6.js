import { check } from "k6";
import http from "k6/http";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";
// import { githubComment } from "https://raw.githubusercontent.com/dotansimha/k6-github-pr-comment/master/lib.js";
import { githubComment } from "https://raw.githubusercontent.com/charlypoly/k6-github-pr-comment/master/lib.js";

export const options = {
  discardResponseBodies: true,
  scenarios: {
    hiveEnabled: {
      executor: "shared-iterations",
      vus: 120,
      iterations: 500,
      maxDuration: "30s",
      env: { GQL_API_PORT: "9292", HIVE_ENABLED: "true" },
    },
    hiveDisabled: {
      executor: "shared-iterations",
      vus: 120,
      iterations: 500,
      maxDuration: "30s",
      startTime: "30s",
      env: { GQL_API_PORT: "9291", HIVE_ENABLED: "false" },
    },
  },
  thresholds: {
    "http_req_duration{hive:enabled}": ["avg<4500"],
    "http_req_duration{hive:disabled}": ["avg<4500"],
  },
};

const QUERY = /* GraphQL */ `
  query GetPost {
    post(id: 1) {
      title
      myId: id
    }
  }
`;

export default function () {
  const payload = JSON.stringify({
    query: QUERY,
    operationName: "GetPost",
  });
  const params = {
    headers: {
      "Content-Type": "application/json",
    },
    tags: { hive: __ENV.HIVE_ENABLED === "true" ? "enabled" : "disabled" },
  };

  return http.post(
    `http://localhost:${__ENV.GQL_API_PORT}/graphql`,
    payload,
    params
  );
}

export function handleSummary(data) {
  let overheadPercentage = null;
  if (
    data.metrics["http_req_duration{hive:enabled}"] &&
    data.metrics["http_req_duration{hive:disabled}"]
  ) {
    const withHive =
      data.metrics["http_req_duration{hive:enabled}"].values["avg"];
    const withoutHive =
      data.metrics["http_req_duration{hive:disabled}"].values["avg"];
    overheadPercentage = 100 - (withHive * 100.0) / withoutHive;
  }
  if (__ENV.GITHUB_TOKEN) {
    githubComment(data, {
      token: __ENV.GITHUB_TOKEN,
      commit: __ENV.GITHUB_SHA,
      pr: __ENV.GITHUB_PR,
      org: "charlypoly",
      repo: "graphql-ruby-hive",
      renderTitle: () => {
        return overheadPercentage < 5
          ? "✅ Benchmark Results"
          : "❌ Benchmark Failed";
      },
      renderMessage: () => {
        const result = [];
        if (overheadPercentage > 5) {
          result.push(
            "**Performance regression detected**: it seems like your Pull Request adds some extra latency to GraphQL Hive operations processing"
          );
        } else {
          result.push("Overhead <= 1%");
        }
        return result.join("\n");
      },
    });
  }
  return {
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
