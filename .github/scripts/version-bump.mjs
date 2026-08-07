#!/usr/bin/env node
// Compara o publish.settings.schema.json antes/depois do push e decide o bump
// de versão (major/minor/patch) com base nas regras de negócio do PubliQ:
//   - novo campo obrigatório (ou campo que virou obrigatório)  -> major
//   - novo campo opcional                                      -> minor
//   - qualquer outra alteração (fix)                            -> patch
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, appendFileSync } from 'node:fs';

const SCHEMA_PATH = 'json/publish.settings.schema.json';

function sh(cmd) {
  return execSync(cmd, { encoding: 'utf8' }).trim();
}

function readJsonAtRef(ref, path) {
  if (!ref || /^0+$/.test(ref)) return null;
  try {
    const content = sh(`git show ${ref}:${path}`);
    return JSON.parse(content);
  } catch {
    return null;
  }
}

// Percorre o schema coletando o caminho de cada campo declarado em
// "properties" e marcando quais deles aparecem no respectivo "required".
function collectFields(node, path, props, required) {
  if (!node || typeof node !== 'object') return;

  if (node.properties && typeof node.properties === 'object') {
    const requiredHere = new Set(node.required || []);
    for (const [key, sub] of Object.entries(node.properties)) {
      const fieldPath = `${path}/${key}`;
      props.add(fieldPath);
      if (requiredHere.has(key)) required.add(fieldPath);
      collectFields(sub, fieldPath, props, required);
    }
  }

  if (node.items) {
    collectFields(node.items, `${path}[]`, props, required);
  }
}

function collectAll(schema) {
  const props = new Set();
  const required = new Set();
  if (!schema) return { props, required };

  collectFields(schema, '#', props, required);

  if (schema.definitions && typeof schema.definitions === 'object') {
    for (const [key, def] of Object.entries(schema.definitions)) {
      collectFields(def, `#/definitions/${key}`, props, required);
    }
  }
  return { props, required };
}

function added(oldSet, newSet) {
  return [...newSet].filter((v) => !oldSet.has(v));
}

function parseSemver(tag) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)$/.exec(tag);
  if (!m) return null;
  return { major: +m[1], minor: +m[2], patch: +m[3] };
}

function getLatestVersion() {
  const tags = sh('git tag --list').split('\n').filter(Boolean);
  const versions = tags.map(parseSemver).filter(Boolean);
  if (versions.length === 0) return { major: 0, minor: 0, patch: 0 };
  versions.sort((a, b) => a.major - b.major || a.minor - b.minor || a.patch - b.patch);
  return versions[versions.length - 1];
}

function main() {
  const beforeSha = process.env.BEFORE_SHA;
  const afterSha = process.env.AFTER_SHA;

  const oldSchema = readJsonAtRef(beforeSha, SCHEMA_PATH);
  const newSchema = existsSync(SCHEMA_PATH)
    ? JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'))
    : readJsonAtRef(afterSha, SCHEMA_PATH);

  const { props: oldProps, required: oldRequired } = collectAll(oldSchema);
  const { props: newProps, required: newRequired } = collectAll(newSchema);

  const addedRequired = added(oldRequired, newRequired);
  const addedOptional = added(oldProps, newProps).filter((f) => !addedRequired.includes(f));

  let bump;
  if (addedRequired.length > 0) {
    bump = 'major';
  } else if (addedOptional.length > 0) {
    bump = 'minor';
  } else {
    bump = 'patch';
  }

  const latest = getLatestVersion();
  const next =
    bump === 'major'
      ? { major: latest.major + 1, minor: 0, patch: 0 }
      : bump === 'minor'
        ? { major: latest.major, minor: latest.minor + 1, patch: 0 }
        : { major: latest.major, minor: latest.minor, patch: latest.patch + 1 };

  const previousVersion = `${latest.major}.${latest.minor}.${latest.patch}`;
  const nextVersion = `${next.major}.${next.minor}.${next.patch}`;

  const outputPath = process.env.GITHUB_OUTPUT;
  if (outputPath) {
    appendFileSync(
      outputPath,
      `bump=${bump}\nprevious_version=${previousVersion}\nnext_version=${nextVersion}\n`,
    );
  }

  const summaryPath = process.env.GITHUB_STEP_SUMMARY;
  if (summaryPath) {
    const lines = [
      '### Versionamento do publish.settings.schema.json',
      '',
      `- Versão anterior: \`${previousVersion}\``,
      `- Próxima versão: \`${nextVersion}\` (**${bump}**)`,
      '',
    ];
    if (addedRequired.length) {
      lines.push('**Campos obrigatórios novos/alterados para obrigatório:**');
      lines.push(...addedRequired.map((f) => `- \`${f}\``));
      lines.push('');
    }
    if (addedOptional.length) {
      lines.push('**Campos opcionais novos:**');
      lines.push(...addedOptional.map((f) => `- \`${f}\``));
      lines.push('');
    }
    if (!addedRequired.length && !addedOptional.length) {
      lines.push('Nenhum campo novo detectado — tratado como correção (fix).');
    }
    appendFileSync(summaryPath, lines.join('\n') + '\n');
  }

  console.log(`bump=${bump} previous=${previousVersion} next=${nextVersion}`);
}

main();
