/**
 * The mrfunnyjokes.app website.
 *
 *   /j/<jokeId>  one joke: setup, tap for the punchline, who told it, Get the app
 *   /            home page: app name, one line, Get the app
 *
 * Pages are built on request, so a joke added to Firestore has a page right away.
 * People with the app never see /j/ pages: the link is a Universal Link and opens
 * the app (see hosting/public/.well-known/apple-app-site-association).
 */

const APP_STORE_ID = "6755938017";

// TODO(Brian): paste the provider token from App Store Connect
// (Analytics > Sources > Campaign link generator shows it as "pt").
// Until it is set, campaign links are left without pt and App Analytics
// will not attribute installs to the campaign.
const PROVIDER_TOKEN = "REPLACE_WITH_PROVIDER_TOKEN";
const CAMPAIGN_TOKEN = "share_card";

const SITE = "https://mrfunnyjokes.app";

const CHARACTERS = {
  mr_funny: { name: "Mr. Funny", image: "mr-funny.jpg", bg: "#FDCA01", ink: "#2A1F00", pill: "#FFFFFF", pillInk: "#2A1F00" },
  mr_love: { name: "Mr. Love", image: "mr-love.jpg", bg: "#D91C72", ink: "#FFFFFF", pill: "#FFFFFF", pillInk: "#B01552" },
  mr_bad: { name: "Mr. Bad", image: "mr-bad.jpg", bg: "#EA2A20", ink: "#FFFFFF", pill: "#FFFFFF", pillInk: "#C81F15" },
  mr_sad: { name: "Mr. Sad", image: "mr-sad.jpg", bg: "#067AF0", ink: "#FFFFFF", pill: "#FFFFFF", pillInk: "#0A3F80" },
  mr_potty: { name: "Mr. Potty", image: "mr-potty.jpg", bg: "#4F270E", ink: "#FFF3DC", pill: "#FFF3DC", pillInk: "#50260E" },
};

function appStoreUrl() {
  const params = new URLSearchParams({ ct: CAMPAIGN_TOKEN, mt: "8" });
  if (PROVIDER_TOKEN && !PROVIDER_TOKEN.startsWith("REPLACE_")) params.set("pt", PROVIDER_TOKEN);
  return `https://apps.apple.com/app/id${APP_STORE_ID}?${params}`;
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Firestore joke IDs are 20 letters and digits; anything else is not a joke link */
function jokeIdFromPath(path) {
  const match = /^\/j\/([A-Za-z0-9_-]{6,64})\/?$/.exec(path);
  return match ? match[1] : null;
}

/**
 * Same rule as the app's JokeTextParser: a blank line marks the punchline.
 * Knock-knock jokes come back as one line per part.
 */
function splitJoke(text, type) {
  const clean = String(text || "").replace(/\r\n/g, "\n").trim();
  const parts = clean.split(/\n[ \t]*\n\s*/);
  const setup = (parts[0] || "").trim();
  const punchline = parts.slice(1).join("\n").trim();
  const isKnockKnock = type === "knock_knock" || /^knock/i.test(clean);
  const lines = (part) => part.split("\n").map((line) => line.trim()).filter(Boolean);
  return { setup, punchline, isKnockKnock, setupLines: lines(setup), punchlineLines: lines(punchline) };
}

function page({ title, description, url, image, theme, body, appArgument }) {
  const smartBanner = `app-id=${APP_STORE_ID}${appArgument ? `, app-argument=${appArgument}` : ""}`;
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
<meta name="theme-color" content="${theme.bg}">
<meta name="apple-itunes-app" content="${escapeHtml(smartBanner)}">
<link rel="canonical" href="${escapeHtml(url)}">
<link rel="icon" href="/img/app-icon.png">
<link rel="apple-touch-icon" href="/img/app-icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Mr. Funny Jokes">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:url" content="${escapeHtml(url)}">
<meta property="og:image" content="${escapeHtml(image)}">
<meta name="twitter:card" content="summary">
<style>
*{box-sizing:border-box;margin:0;padding:0}
html{-webkit-text-size-adjust:100%}
body{min-height:100vh;min-height:100dvh;background:${theme.bg};color:${theme.ink};
  font-family:ui-rounded,"SF Pro Rounded",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
  display:flex;justify-content:center;overflow-x:hidden}
main{position:relative;width:100%;max-width:560px;min-height:100vh;min-height:100dvh;display:flex;flex-direction:column;
  padding:max(28px,env(safe-area-inset-top)) 24px max(24px,env(safe-area-inset-bottom))}
.brand{display:flex;align-items:center;gap:10px;font-weight:800;font-size:17px;color:inherit;text-decoration:none}
.brand img{width:36px;height:36px;border-radius:9px}
.label{margin-top:34px;font-size:16px;font-weight:800}
h1{margin-top:12px;font-size:clamp(30px,9.4vw,46px);line-height:1.12;font-weight:900;letter-spacing:-.01em;text-wrap:balance}
h1.long{font-size:clamp(24px,7vw,34px)}
.pill{display:inline-block;margin-top:20px;padding:.5em .75em;border-radius:.8em;background:${theme.pill};color:${theme.pillInk};
  font-size:clamp(23px,7vw,34px);line-height:1.15;font-weight:900;transform:rotate(-2deg);transform-origin:left center;
  box-shadow:0 10px 24px rgba(0,0,0,.14)}
.pill.long{font-size:clamp(19px,5.4vw,26px);transform:none}
.reveal{margin-top:22px;border:0;background:none;color:inherit;font:inherit;font-size:16px;font-weight:800;opacity:.8;cursor:pointer;padding:10px 0}
.hidden{display:none}
.pop{animation:pop .42s cubic-bezier(.3,1.5,.5,1)}
@keyframes pop{from{opacity:0;transform:scale(.5) rotate(-2deg)}}
.chat{margin-top:16px;display:flex;flex-direction:column;gap:10px}
.bubble{max-width:82%;padding:.5em .8em;border-radius:1em;font-size:clamp(20px,6vw,28px);line-height:1.15;font-weight:900}
.bubble.teller{align-self:flex-start;background:${theme.pill};color:${theme.pillInk};border-bottom-left-radius:.3em}
.bubble.reply{align-self:flex-end;background:rgba(0,0,0,.72);color:#fff;border-bottom-right-radius:.3em}
.spacer{flex:1;min-height:200px}
.face{position:absolute;right:-24px;bottom:96px;width:min(78%,360px);aspect-ratio:1;z-index:0;pointer-events:none;
  background:url(/img/${theme.image}) center/cover;
  -webkit-mask-image:linear-gradient(to right,transparent,#000 22%),linear-gradient(to bottom,transparent,#000 16%);
  -webkit-mask-composite:source-in;mask-image:linear-gradient(to right,transparent,#000 22%),linear-gradient(to bottom,transparent,#000 16%);
  mask-composite:intersect}
.content{position:relative;z-index:1}
.cta{position:relative;z-index:1;display:block;text-align:center;text-decoration:none;background:#000;color:#fff;
  font-size:18px;font-weight:800;padding:17px 20px;border-radius:999px}
.sub{position:relative;z-index:1;margin-top:12px;text-align:center;font-size:13px;font-weight:600;opacity:.8}
.sub a{color:inherit}
@media (prefers-reduced-motion:reduce){.pop{animation:none}}
</style>
</head>
<body>
<main>
${body}
<a class="cta" href="${escapeHtml(appStoreUrl())}">Get the app</a>
<p class="sub">Mr. Funny Jokes for iPhone · <a href="/privacy">Privacy</a></p>
</main>
</body>
</html>`;
}

function brand() {
  return `<a class="brand" href="/"><img src="/img/app-icon.png" alt="">Mr. Funny Jokes</a>`;
}

function homePage() {
  const theme = CHARACTERS.mr_funny;
  const body = `<div class="content">
${brand()}
<h1 style="margin-top:34px">Dad jokes so bad they're good.</h1>
<p class="label" style="margin-top:16px;font-weight:700">Puns, pickup lines, knock-knocks and a new Joke of the Day, from Mr. Funny and friends.</p>
</div>
<div class="face" role="presentation"></div>
<div class="spacer"></div>`;
  return page({
    title: "Mr. Funny Jokes",
    description: "Dad jokes, puns, pickup lines and a new Joke of the Day, from Mr. Funny and friends.",
    url: `${SITE}/`,
    image: `${SITE}/img/app-icon.png`,
    theme,
    body,
  });
}

function jokePage(id, joke) {
  const theme = CHARACTERS[joke.character] || CHARACTERS.mr_funny;
  const { setup, punchline, isKnockKnock, setupLines, punchlineLines } = splitJoke(joke.text, joke.type);
  const url = `${SITE}/j/${id}`;

  let jokeHtml;
  if (isKnockKnock) {
    const bubble = (line, hidden) => {
      const isReply = /^who['’]s there/i.test(line) || /who\?$/i.test(line);
      return `<div class="bubble ${isReply ? "reply" : "teller"}${hidden ? " hidden js-punch" : ""}">${escapeHtml(line)}</div>`;
    };
    jokeHtml = `<div class="chat">
${setupLines.map((line) => bubble(line, false)).join("\n")}
${punchlineLines.map((line) => bubble(line, true)).join("\n")}
</div>`;
  } else {
    const long = setup.length > 90 ? " long" : "";
    const longPill = punchline.length > 60 ? " long" : "";
    jokeHtml = `<h1 class="${long.trim()}">${escapeHtml(setup)}</h1>
${punchline ? `<div><div class="pill${longPill} hidden js-punch">${escapeHtml(punchline)}</div></div>` : ""}`;
  }

  const hasPunchline = punchlineLines.length > 0;
  const body = `<div class="content">
${brand()}
<p class="label">${escapeHtml(theme.name)}</p>
${jokeHtml}
${hasPunchline ? `<button class="reveal js-reveal" type="button">👆 Tap for the punchline</button>` : ""}
</div>
<div class="face" role="img" aria-label="${escapeHtml(theme.name)}"></div>
<div class="spacer"></div>
<noscript><style>.hidden{display:revert}.reveal{display:none}</style></noscript>
<script>
(function () {
  var button = document.querySelector(".js-reveal");
  if (!button) return;
  function reveal() {
    document.querySelectorAll(".js-punch").forEach(function (el, i) {
      setTimeout(function () { el.classList.remove("hidden"); el.classList.add("pop"); }, i * 550);
    });
    button.remove();
    document.removeEventListener("click", onClick);
  }
  function onClick(event) { if (!event.target.closest("a")) reveal(); }
  document.addEventListener("click", onClick);
})();
</script>`;

  // The link preview shows the setup only, so the punchline is still a surprise
  const teaser = isKnockKnock ? setupLines.join(" ") : setup;
  return page({
    title: teaser,
    description: `${hasPunchline ? "Tap for the punchline. " : ""}A joke from ${theme.name} in Mr. Funny Jokes.`,
    url,
    image: `${SITE}/img/${theme.image}`,
    theme,
    body,
    appArgument: url,
  });
}

/** Express-style handler, given the Firestore instance to read jokes from */
function createHandler(db) {
  return async (req, res) => {
    const id = jokeIdFromPath(req.path);
    if (id) {
      try {
        const snapshot = await db.collection("jokes").doc(id).get();
        if (snapshot.exists) {
          res.set("Cache-Control", "public, max-age=300, s-maxage=3600");
          res.status(200).send(jokePage(id, snapshot.data()));
          return;
        }
      } catch (error) {
        console.error("Joke page failed", { id, message: error.message });
      }
    }
    // The home page, and any joke link that doesn't name a joke
    res.set("Cache-Control", id ? "public, max-age=60" : "public, max-age=300, s-maxage=3600");
    res.status(200).send(homePage());
  };
}

module.exports = { createHandler, homePage, jokePage, splitJoke, jokeIdFromPath, appStoreUrl };
