// 生成 shared_preferences 的 Android XML 种子数据，用于模拟器截图验证
// 输出：tools/seed.xml
const fs = require('fs');
const path = require('path');

const cardId = 'card-hongye-0001';

const card = {
  id: cardId,
  name: '红叶',
  persona:
    '山间温泉旅馆「红叶亭」的年轻老板娘。说话轻缓，尾音总留半分余地；对熟人偶尔露出促狭的一面。习惯先替客人着想，再谈自己。',
  appearance:
    '墨色长发松松绾在脑后，只别一支素木簪。藏青色碎花和服，袖口沾着一点炭灰。指尖有常年烧水的薄茧，走路很轻。',
  avatar: '🍁',
  colorIndex: 2,
  createdAt: new Date('2026-09-17T09:00:00Z').toISOString(),
};

const user = {
  name: '旅人',
  persona: '独自翻山而来的旅人，随身只有一只旧行囊与半卷未读完的书。',
  avatar: '🍃',
  colorIndex: 1,
};

const msg = (role, content, reasoning, showReasoning, min) => ({
  id: 'm' + min,
  role,
  content,
  reasoning: reasoning || null,
  showReasoning: !!showReasoning,
  at: new Date(Date.UTC(2026, 8, 17, 10, min, 0)).toISOString(),
  characterId: role === 'assistant' ? cardId : null,
  error: null,
});

const messages = [
  msg('user', '（掀开布帘，带进一阵山风）请问……还留着房间吗？', null, false, 2),
  msg(
    'assistant',
    '（从灶台边直起身，用围裙擦了擦手）有的。这个时节上山的人不多，靠里那间一直空着。\n\n（接过你的行囊，放在檐下干燥处）先坐吧，我给你倒碗热的。',
    '客人带着山风进来，说明是从北面的坡道上来的。这个时辰走那条路，多半是走了很久。\n先安顿，再问来处——不要一上来就打听人家的行程。',
    true,
    3
  ),
  msg('user', '多谢。这汤是……？', null, false, 5),
  msg(
    'assistant',
    '（把粗陶碗推到你面前，热气晕开）山菌和萝卜，熬了一下午，没什么讲究。\n\n（在对面坐下，双手拢着袖口）倒是你——这个季节翻山，是有什么非去不可的地方吗？',
    null,
    true,
    6
  ),
  msg('user', '算是吧。想找个能安静看雪的地方。', null, false, 8),
  msg(
    'assistant',
    '（笑了一下，眼角有很浅的纹）那你来对地方了。\n\n再往里走三天，是「霜见岳」。雪要下到十一月，那时候整面山都是白的，安静得能听见雪落在枝上的声音。\n\n（顿了顿，把火拨得更旺些）不过今晚先别想那么远。碗里的汤要凉了。',
    null,
    false,
    9
  ),
];

const session = {
  id: cardId,
  characterId: cardId,
  world:
    '明治四十四年的秋末，北岭山道尽头有一间温泉旅馆「红叶亭」。\n旅人自山下来，山中已连着下了三日冷雨，霜降将至。\n旅馆只有老板娘红叶一人打理。',
  messages,
  updatedAt: new Date().toISOString(),
};

const api = {
  baseUrl: 'https://api.deepseek.com',
  apiKey: '',
  model: 'deepseek-chat',
  reasoning: 'off',
  sendReasoningEffort: false,
  temperature: 1.1,
  maxTokens: 2048,
  stream: true,
  extraJson: '',
};

const esc = (s) =>
  s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/'/g, '&apos;');

const J = (o) => esc(JSON.stringify(o));

const xml = `<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="flutter.tavern.cards.v1">${J([card])}</string>
    <string name="flutter.tavern.sessions.v1">${J([session])}</string>
    <string name="flutter.tavern.user.v1">${J(user)}</string>
    <string name="flutter.tavern.api.v1">${J(api)}</string>
    <string name="flutter.tavern.active.v1">${esc(cardId)}</string>
</map>
`;

const out = path.join(__dirname, 'seed.xml');
fs.writeFileSync(out, xml, 'utf8');
console.log('wrote ' + out + ' (' + xml.length + ' bytes)');
