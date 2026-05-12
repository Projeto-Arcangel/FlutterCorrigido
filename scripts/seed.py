import firebase_admin
from firebase_admin import credentials, firestore
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
key_path = os.path.join(script_dir, 'serviceAccountKey.json')

cred = credentials.Certificate(key_path)
firebase_admin.initialize_app(cred, {'projectId': 'casoeuerre-8g1y00'})
db = firestore.client()

phases = [
    {
        'data': {
            'name': 'Brasil Colônia',
            'description': 'Conheça o período colonial do Brasil, da chegada dos portugueses até as transformações do século XVIII.',
            'order': 1,
        },
        'questions': [
            {
                'text': 'Em que ano Pedro Álvares Cabral chegou ao Brasil?',
                'options': ['1498', '1500', '1502', '1510'],
                'correct_answer': 1,
                'explanation': 'Pedro Álvares Cabral chegou ao Brasil em 22 de abril de 1500, durante uma expedição rumo à Índia.',
                'type': 0,
            },
            {
                'text': 'Qual era o principal produto de exportação do Brasil durante o século XVI?',
                'options': ['Ouro', 'Açúcar', 'Pau-brasil', 'Café'],
                'correct_answer': 2,
                'explanation': 'O pau-brasil foi o primeiro produto explorado pelos portugueses, utilizado como corante na Europa.',
                'type': 0,
            },
            {
                'text': 'O Brasil foi dividido em Capitanias Hereditárias para facilitar a colonização.',
                'options': ['Verdadeiro', 'Falso'],
                'correct_answer': 0,
                'explanation': 'Em 1532, D. João III dividiu o Brasil em 15 faixas de terra denominadas Capitanias Hereditárias.',
                'type': 2,
            },
            {
                'text': 'Qual ordem religiosa teve papel central na catequização dos indígenas no Brasil colonial?',
                'options': ['Franciscanos', 'Dominicanos', 'Jesuítas', 'Beneditinos'],
                'correct_answer': 2,
                'explanation': 'Os jesuítas chegaram ao Brasil em 1549 e foram os principais responsáveis pela catequização dos povos indígenas.',
                'type': 0,
            },
        ],
    },
    {
        'data': {
            'name': 'Brasil Imperial',
            'description': 'Do período joanino à proclamação da república: entenda como o Brasil se tornou um império independente.',
            'order': 2,
        },
        'questions': [
            {
                'text': 'Em que ano o Brasil declarou independência de Portugal?',
                'options': ['1808', '1815', '1822', '1831'],
                'correct_answer': 2,
                'explanation': 'A independência foi declarada por Dom Pedro I em 7 de setembro de 1822, às margens do Rio Ipiranga.',
                'type': 0,
            },
            {
                'text': 'Quem proclamou a República no Brasil em 1889?',
                'options': ['Dom Pedro II', 'Marechal Deodoro da Fonseca', 'Floriano Peixoto', 'Tiradentes'],
                'correct_answer': 1,
                'explanation': 'Marechal Deodoro da Fonseca proclamou a República em 15 de novembro de 1889.',
                'type': 0,
            },
            {
                'text': 'A Lei Áurea, assinada em 1888, aboliu a escravidão no Brasil.',
                'options': ['Verdadeiro', 'Falso'],
                'correct_answer': 0,
                'explanation': 'A Princesa Isabel assinou a Lei Áurea em 13 de maio de 1888, tornando o Brasil o último país das Américas a abolir a escravidão.',
                'type': 2,
            },
            {
                'text': 'Como ficou conhecido o período em que Dom João VI governou o Brasil?',
                'options': ['Período Regencial', 'Período Joanino', 'Segundo Reinado', 'República Velha'],
                'correct_answer': 1,
                'explanation': 'O Período Joanino (1808–1821) foi o tempo em que Dom João VI governou o Brasil após a transferência da Corte Portuguesa.',
                'type': 0,
            },
        ],
    },
    {
        'data': {
            'name': 'República Velha',
            'description': 'Explore os primeiros anos da república brasileira, a política do café com leite e os movimentos sociais do início do século XX.',
            'order': 3,
        },
        'questions': [
            {
                'text': 'O que era a "Política do Café com Leite"?',
                'options': [
                    'Uma aliança entre Rio de Janeiro e Minas Gerais',
                    'Um acordo entre São Paulo e Minas Gerais para alternância na presidência',
                    'Uma política de incentivo à exportação de café e leite',
                    'Uma reunião dos presidentes do Nordeste',
                ],
                'correct_answer': 1,
                'explanation': 'Era um acordo entre São Paulo e Minas Gerais para alternarem na presidência da República.',
                'type': 0,
            },
            {
                'text': 'A Semana de Arte Moderna de 1922 aconteceu em qual cidade?',
                'options': ['Rio de Janeiro', 'Salvador', 'São Paulo', 'Belo Horizonte'],
                'correct_answer': 2,
                'explanation': 'Ocorreu em São Paulo, no Teatro Municipal, em fevereiro de 1922.',
                'type': 0,
            },
            {
                'text': 'A República Velha foi marcada pelo domínio político das oligarquias agrárias.',
                'options': ['Verdadeiro', 'Falso'],
                'correct_answer': 0,
                'explanation': 'Durante a República Velha (1889–1930), o poder era controlado pelas oligarquias dos estados mais ricos.',
                'type': 2,
            },
            {
                'text': 'Qual evento encerrou a República Velha no Brasil?',
                'options': [
                    'A morte de Epitácio Pessoa',
                    'A Revolução de 1930 liderada por Getúlio Vargas',
                    'A aprovação de uma nova Constituição',
                    'A Guerra do Contestado',
                ],
                'correct_answer': 1,
                'explanation': 'A República Velha foi encerrada pela Revolução de 1930, que levou Getúlio Vargas ao poder.',
                'type': 0,
            },
        ],
    },
]

def seed():
    print('Iniciando seed do Firestore...\n')

    for phase in phases:
        phase_ref = db.collection('Phase').document()
        phase_ref.set(phase['data'])
        print(f"Phase criada: \"{phase['data']['name']}\" (id: {phase_ref.id})")

        for question in phase['questions']:
            db.collection('Questions').document().set({
                **question,
                'phase_ref': phase_ref,
            })
        print(f"   {len(phase['questions'])} questoes inseridas\n")

    print('Seed concluido com sucesso!')

seed()
