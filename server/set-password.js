// Setzt das Passwort eines Server-Kontos direkt in der Datenbank.
//
// Gedacht fuer alte Konten ohne Passwort, die der Server seit der
// Passwortpflicht ablehnt, und fuer vergessene Passwoerter.
//
//   node server/set-password.js <benutzername>
//   docker compose exec studiumsplaner node server/set-password.js <benutzername>
//
// Das Passwort wird zweimal abgefragt und nicht angezeigt. Fuer Skripte kann
// es stattdessen ueber die Umgebungsvariable STUDIPLAN_PASSWORD kommen.
import bcrypt from 'bcryptjs';
import Database from 'better-sqlite3';
import { existsSync } from 'node:fs';
import readline from 'node:readline';

const MIN_PASSWORD_LENGTH = 8;
const MAX_PASSWORD_LENGTH = 128;
const DB_PATH = process.env.DB_PATH || '/data/studiumsplaner.db';

function fail(message) {
  console.error(message);
  process.exit(1);
}

function askHidden(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: true,
    });
    // Eingabe nicht anzeigen: nur die Frage selbst ausgeben.
    rl._writeToOutput = (text) => {
      if (text.includes(question)) process.stdout.write(text);
    };
    rl.question(question, (answer) => {
      rl.close();
      process.stdout.write('\n');
      resolve(answer);
    });
  });
}

const username = process.argv[2]?.trim();
if (!username) {
  fail('Aufruf: node server/set-password.js <benutzername>');
}
if (!existsSync(DB_PATH)) {
  fail(`Datenbank nicht gefunden: ${DB_PATH} (DB_PATH setzen?)`);
}

const db = new Database(DB_PATH);
const user = db
  .prepare('SELECT id, password_hash FROM users WHERE username = ?')
  .get(username);
if (!user) {
  fail(`Benutzer "${username}" nicht gefunden.`);
}

let password = process.env.STUDIPLAN_PASSWORD;
if (password === undefined) {
  if (!process.stdin.isTTY) {
    fail('Kein Terminal: Passwort ueber STUDIPLAN_PASSWORD uebergeben.');
  }
  password = await askHidden('Neues Passwort: ');
  const repeated = await askHidden('Passwort wiederholen: ');
  if (password !== repeated) {
    fail('Die Passwoerter stimmen nicht ueberein.');
  }
}

if (password.length < MIN_PASSWORD_LENGTH) {
  fail(`Passwort zu kurz (mindestens ${MIN_PASSWORD_LENGTH} Zeichen).`);
}
if (password.length > MAX_PASSWORD_LENGTH) {
  fail('Passwort zu lang.');
}

const hash = await bcrypt.hash(password, 12);
db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(hash, user.id);
db.close();

console.log(
  user.password_hash === null
    ? `Passwort fuer "${username}" gesetzt. Das Konto ist wieder nutzbar.`
    : `Passwort fuer "${username}" geaendert.`,
);
console.log(
  'Laufende Anmeldungen bleiben bis zum Ablauf (24 h) oder Server-Neustart gueltig.',
);
