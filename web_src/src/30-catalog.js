/* ---------- catálogo: esportes, matérias e modelos de atividade ---------- */
var SPORTS = [
  ['futebol', 'Futebol'], ['futsal', 'Futsal'], ['volei', 'Vôlei'], ['basquete', 'Basquete'], ['handebol', 'Handebol'],
  ['corrida', 'Corrida'], ['caminhada', 'Caminhada'], ['bike', 'Bicicleta'], ['natacao', 'Natação'], ['danca', 'Dança'],
  ['treino', 'Treino em casa'], ['musculacao', 'Musculação'], ['luta', 'Lutas e capoeira'], ['skate', 'Skate ou patins'],
  ['corda', 'Pular corda'], ['yoga', 'Alongamento e ioga'], ['tenis', 'Tênis ou tênis de mesa'], ['ginastica', 'Ginástica']
];
var SUBJECTS = ['Matemática', 'Português', 'Redação', 'Literatura', 'Inglês', 'Espanhol', 'História', 'Geografia', 'Ciências', 'Biologia', 'Física', 'Química', 'Filosofia', 'Sociologia', 'Artes'];

/* local: c = em casa, f = ao ar livre, q = em qualquer lugar, l = no local de treino · energia: t, m, a */
var PLACE_LABEL = { c: 'Em casa', f: 'Ao ar livre', q: 'Em qualquer lugar', l: 'No seu local de treino' };
var ENERGY_LABEL = { t: 'Tranquilo', m: 'Moderado', a: 'Ativo' };
var KIND_LABEL = { estudo: 'Estudo', exercicio: 'Exercício', pausa: 'Pausa' };

var SPORT_TPL = {
  futebol: [['Aquecimento com trote e alongamento', 5, 'f', 'm'], ['Embaixadinhas: tente bater seu recorde', 10, 'f', 'm'], ['Passes e domínio contra a parede', 10, 'f', 'm'], ['Condução de bola entre obstáculos', 20, 'f', 'a'], ['Chutes em um alvo', 20, 'f', 'a'], ['Jogar uma partida com amigos', 30, 'f', 'a']],
  futsal: [['Aquecimento com trote e alongamento', 5, 'f', 'm'], ['Domínio de bola com a sola do pé', 10, 'f', 'm'], ['Passes curtos contra a parede', 10, 'f', 'm'], ['Dribles curtos entre obstáculos', 20, 'f', 'a'], ['Jogar uma partida com amigos', 30, 'f', 'a']],
  volei: [['Posição de expectativa e deslocamentos', 5, 'c', 'm'], ['Toques e manchetes contra a parede', 10, 'f', 'm'], ['Treinar o saque', 20, 'f', 'm'], ['Jogar com amigos', 30, 'f', 'a']],
  basquete: [['Controle de bola parado, com as duas mãos', 5, 'c', 't'], ['Dribles em movimento', 10, 'f', 'm'], ['Arremessos de perto da cesta', 20, 'f', 'm'], ['Bandejas pelos dois lados', 20, 'f', 'a'], ['Jogar com amigos', 30, 'f', 'a']],
  handebol: [['Deslocamentos laterais e de costas', 5, 'c', 'a'], ['Passes contra a parede com as duas mãos', 10, 'f', 'm'], ['Arremessos em um alvo', 20, 'f', 'a'], ['Jogar com amigos', 30, 'f', 'a']],
  corrida: [['Aquecimento: trote leve e mobilidade', 5, 'f', 'm'], ['Intercalar 1 minuto de corrida e 1 de caminhada', 10, 'f', 'm'], ['Corrida leve, em ritmo de conversa', 20, 'f', 'a'], ['Corrida contínua em ritmo confortável', 30, 'f', 'a']],
  caminhada: [['Volta rápida no quarteirão', 5, 'f', 't'], ['Caminhada curta', 10, 'f', 't'], ['Caminhada em ritmo confortável', 20, 'f', 'm'], ['Caminhada mais longa', 30, 'f', 'm']],
  bike: [['Conferir pneus e freios antes de sair', 5, 'c', 't'], ['Pedalada curta em ritmo leve', 10, 'f', 'm'], ['Pedalar em ritmo leve', 20, 'f', 'm'], ['Pedalar por um trajeto conhecido', 30, 'f', 'a']],
  natacao: [['Mobilidade de ombros e braços', 5, 'c', 't'], ['Fortalecer pernas e abdômen fora da água', 10, 'c', 'm'], ['Treinar a braçada e a respiração fora da água', 20, 'c', 'm'], ['Nadar em ritmo confortável, se você tiver acesso a uma piscina', 30, 'l', 'a']],
  danca: [['Soltar o corpo com uma música', 5, 'c', 't'], ['Dançar três músicas seguidas', 10, 'c', 'a'], ['Ensaiar uma coreografia', 20, 'c', 'a'], ['Ensaio completo de dança', 30, 'c', 'a']],
  treino: [['Polichinelos e agachamentos', 5, 'c', 'a'], ['Prancha e abdominais', 10, 'c', 'm'], ['Circuito: agachamento, flexão e prancha', 10, 'c', 'a'], ['Circuito completo com o peso do corpo', 20, 'c', 'a'], ['Treino completo: pernas, braços e abdômen', 30, 'c', 'a']],
  musculacao: [['Aquecimento e mobilidade das articulações', 5, 'q', 'm'], ['Flexões e agachamentos com boa postura', 10, 'c', 'a'], ['Treino de força com o peso do corpo', 20, 'c', 'a'], ['Seu treino de academia, se você já frequenta uma', 30, 'l', 'a']],
  luta: [['Alongar quadris e pernas', 5, 'c', 't'], ['Base, guarda e esquivas', 10, 'c', 'm'], ['Sombra: golpes no ar com técnica', 10, 'c', 'a'], ['Sequência de movimentos básicos da sua modalidade', 20, 'c', 'a'], ['Treino completo da sua modalidade', 30, 'l', 'a']],
  skate: [['Equilíbrio parado sobre o skate ou os patins', 5, 'f', 't'], ['Remadas e curvas em um lugar seguro', 10, 'f', 'm'], ['Andar com equipamento de proteção', 20, 'f', 'a'], ['Sessão livre em um lugar seguro', 30, 'f', 'a']],
  corda: [['Pular corda em blocos de 1 minuto', 5, 'q', 'a'], ['Pular corda com pausas curtas', 10, 'q', 'a'], ['Corda e agachamentos alternados', 20, 'q', 'a']],
  yoga: [['Respiração lenta e postura', 5, 'q', 't'], ['Alongar pescoço, ombros e punhos', 5, 'q', 't'], ['Alongamento do corpo todo', 10, 'c', 't'], ['Sequência de ioga para iniciantes', 20, 'c', 't'], ['Prática longa de ioga e relaxamento', 30, 'c', 't']],
  tenis: [['Deslocamentos laterais e base', 5, 'c', 'a'], ['Bater bola contra a parede', 10, 'f', 'm'], ['Treinar o saque', 20, 'f', 'm'], ['Jogar com alguém', 30, 'l', 'a']],
  ginastica: [['Equilíbrio em um pé só e postura', 5, 'c', 't'], ['Flexibilidade: pernas e coluna', 10, 'c', 't'], ['Sequência simples de solo', 20, 'c', 'm'], ['Treino completo de ginástica', 30, 'l', 'a']]
};
var CUSTOM_SPORT_TPL = [['Aquecimento para {x}', 5, 'q', 'm'], ['Treinar um fundamento de {x}', 10, 'l', 'm'], ['Praticar {x}', 20, 'l', 'a'], ['Sessão completa de {x}', 30, 'l', 'a']];
var GENERAL_MOVE = [
  ['Alongar pescoço, ombros e punhos', 5, 'q', 't'], ['Levantar, beber água e andar um pouco', 5, 'q', 't'], ['Polichinelos e agachamentos', 5, 'c', 'a'],
  ['Caminhada curta', 10, 'f', 't'], ['Alongamento do corpo todo', 10, 'c', 't'], ['Circuito: agachamento, flexão e prancha', 10, 'c', 'a'],
  ['Caminhada em ritmo confortável', 20, 'f', 'm'], ['Dançar ao som das suas músicas', 20, 'c', 'a'], ['Caminhada mais longa', 30, 'f', 'm']
];

/* {a} = matéria (e assunto da prova, se houver) · {m} = só a matéria */
var STUDY_TPL = [
  ['kw', 'Rever títulos e palavras-chave: {a}', 5, 'q', 't'],
  ['dv', 'Anotar 3 dúvidas para perguntar na aula: {m}', 5, 'q', 't'],
  ['rv', 'Revisar as anotações: {a}', 10, 'q', 't'],
  ['vz', 'Explicar em voz alta, como se desse aula: {a}', 10, 'c', 'm'],
  ['ex', 'Resolver 5 exercícios: {a}', 20, 'c', 'm'],
  ['rs', 'Fazer um resumo em meia página: {a}', 20, 'c', 't'],
  ['fc', 'Criar cartões de pergunta e resposta: {a}', 20, 'q', 't'],
  ['er', 'Refazer as questões que você errou: {m}', 30, 'c', 'm'],
  ['sm', 'Simulado curto com tempo marcado: 10 questões de {m}', 30, 'c', 'a']
];
var FORMULAS = [['m1', 'Refazer 3 exercícios resolvidos em aula: {a}', 10, 'c', 'm'], ['m2', 'Montar uma folha de fórmulas: {a}', 20, 'c', 't']];
var IDIOMA = [['i1', 'Revisar 10 palavras novas: {m}', 5, 'q', 't'], ['i2', 'Ler um texto curto e anotar o que entendeu: {m}', 10, 'q', 'm']];
var LEITURA = [['l1', 'Ler 10 páginas do livro que a escola pediu', 20, 'q', 't'], ['l2', 'Anotar personagens e ideias principais do livro', 10, 'q', 't']];
var STUDY_EXTRA = {
  'Matemática': FORMULAS, 'Física': FORMULAS, 'Química': FORMULAS,
  'Inglês': IDIOMA, 'Espanhol': IDIOMA,
  'Português': LEITURA, 'Literatura': LEITURA,
  'Redação': [['r1', 'Escrever um parágrafo de introdução', 10, 'c', 'm'], ['r2', 'Planejar uma redação: tese e dois argumentos', 20, 'c', 'm'], ['r3', 'Escrever uma redação completa', 30, 'c', 'a']]
};
var STUDY_SKIP = { 'Redação': ['ex', 'er', 'sm', 'fc', 'kw'] };
var GENERAL_STUDY = [
  ['Organizar o material e a mesa de estudo', 5, 'c', 't'], ['Listar as tarefas e provas da semana', 5, 'q', 't'],
  ['Revisar a matéria que você viu hoje', 10, 'q', 't'], ['Resolver exercícios da matéria com mais dúvidas', 20, 'c', 'm'],
  ['Ler 10 páginas do livro que a escola pediu', 20, 'q', 't'], ['Fazer primeiro a tarefa de casa mais difícil', 30, 'c', 'm']
];
var PAUSE_IDEAS = ['Alongar pescoço, ombros e punhos', 'Levantar, beber água e andar um pouco', 'Olhar para longe e descansar os olhos', 'Respirar fundo, devagar, dez vezes', 'Arrumar a mesa de estudo'];

function sportName(id) {
  if (!id) return '';
  if (id.indexOf('c:') === 0) return id.slice(2);
  for (var i = 0; i < SPORTS.length; i++) if (SPORTS[i][0] === id) return SPORTS[i][1];
  return id;
}
function upcomingExams(d) {
  var t = dayKey();
  return d.prefs.exams.filter(function (e) { return !e.date || e.date >= t; }).sort(function (a, b) {
    var x = a.date || '9999', y = b.date || '9999';
    return x < y ? -1 : (x > y ? 1 : 0);
  });
}
function pastExams(d) { var t = dayKey(); return d.prefs.exams.filter(function (e) { return e.date && e.date < t; }); }
function bucket(min) { return min <= 7 ? 5 : (min <= 14 ? 10 : (min <= 24 ? 20 : 30)); }

function buildActivities(d) {
  var out = [], seen = {}, today = dayKey(), exams = upcomingExams(d);
  function add(a) {
    var k = a.kind + '|' + a.title + '|' + a.min;
    if (seen[k]) return;
    seen[k] = 1;
    out.push(a);
  }
  d.custom.forEach(function (c) {
    add({ id: 'c:' + c.id, kind: c.kind, title: c.title, min: c.min, place: c.place, energy: c.energy, custom: true, customId: c.id });
  });
  d.prefs.subjects.forEach(function (m) {
    var exam = null;
    for (var i = 0; i < exams.length; i++) if (exams[i].subject === m) { exam = exams[i]; break; }
    var a = (exam && exam.topic) ? (m + ' · ' + exam.topic) : m;
    var days = (exam && exam.date) ? diffDays(exam.date, today) : null;
    var hard = d.prefs.hard.indexOf(m) >= 0, skip = STUDY_SKIP[m] || [];
    STUDY_TPL.concat(STUDY_EXTRA[m] || []).forEach(function (t) {
      if (skip.indexOf(t[0]) >= 0) return;
      add({
        id: 'st:' + t[0] + ':' + slug(m), kind: 'estudo', title: t[1].replace('{a}', a).replace('{m}', m), min: t[2], place: t[3], energy: t[4],
        subject: m, hasExam: !!exam, examDays: days, hard: hard
      });
    });
  });
  GENERAL_STUDY.forEach(function (t, i) {
    if (d.prefs.subjects.length && i > 1) return;
    add({ id: 'gs:' + slug(t[0]), kind: 'estudo', title: t[0], min: t[1], place: t[2], energy: t[3], general: true });
  });
  d.prefs.sports.forEach(function (id) {
    if (id.indexOf('c:') === 0) {
      var nm = id.slice(2);
      CUSTOM_SPORT_TPL.forEach(function (t) {
        add({ id: 'ex:' + slug(nm) + ':' + slug(t[0]) + ':' + t[1], kind: 'exercicio', title: t[0].replace('{x}', nm), min: t[1], place: t[2], energy: t[3], sport: id });
      });
      return;
    }
    (SPORT_TPL[id] || []).forEach(function (t) {
      add({ id: 'ex:' + id + ':' + slug(t[0]) + ':' + t[1], kind: 'exercicio', title: t[0], min: t[1], place: t[2], energy: t[3], sport: id });
    });
  });
  GENERAL_MOVE.forEach(function (t) {
    add({ id: 'gx:' + slug(t[0]) + ':' + t[1], kind: 'exercicio', title: t[0], min: t[1], place: t[2], energy: t[3], general: true });
  });
  return out;
}

function placeMatch(p, f) {
  if (f === 'c') return p === 'c' || p === 'q';
  if (f === 'f') return p === 'f' || p === 'q';
  return p === 'q';
}
function filterActs(list, f) {
  return list.filter(function (a) {
    return (!f.kind || a.kind === f.kind) && (!f.dur || bucket(a.min) === f.dur) && (!f.place || placeMatch(a.place, f.place)) && (!f.energy || a.energy === f.energy);
  });
}
function scoreAct(a, d, day) {
  var s = hashStr(a.id + day) % 18;
  if (a.kind === 'estudo') {
    if (a.examDays != null) s += a.examDays <= 2 ? 60 : (a.examDays <= 7 ? 45 : (a.examDays <= 14 ? 25 : 8));
    else if (a.hasExam) s += 8;
    if (a.hard) s += 20;
  } else if (a.sport) s += 25;
  if (a.general) s -= 6;
  if (a.custom) s += 30;
  if (d.fav.indexOf(a.id) >= 0) s += 15;
  return s;
}
/* ordena por relevância e alterna estudo e exercício, para a lista não pender para um lado só */
function rankActs(list, d) {
  var day = dayKey(), a = [], b = [], out = [];
  list.forEach(function (x) { x._s = scoreAct(x, d, day); (x.kind === 'estudo' ? a : b).push(x); });
  function cmp(x, y) { return y._s - x._s || (x.id < y.id ? -1 : 1); }
  a.sort(cmp); b.sort(cmp);
  while (a.length || b.length) {
    if (a.length) out.push(a.shift());
    if (b.length) out.push(b.shift());
  }
  return out;
}
function actById(d, id) {
  var list = buildActivities(d);
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i];
  return null;
}
function actTags(a) {
  var tags = [];
  if (a.examDays != null) tags.push(a.examDays === 0 ? 'Prova hoje' : (a.examDays === 1 ? 'Prova amanhã' : 'Prova em ' + a.examDays + ' dias'));
  else if (a.hasExam) tags.push('Tem prova marcada');
  if (a.hard) tags.push('Matéria com mais dificuldade');
  if (a.custom) tags.push('Criada por você');
  return tags;
}
