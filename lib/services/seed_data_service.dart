import '../models/subject_model.dart';
import '../models/question_model.dart';

class SeedDataService {
  static List<Subject> getSubjects() {
    return const [
      Subject(
        id: 'subj_fil',
        name: 'Filipino',
        description: 'Wika, Balarila, Sawikain, at Panitikang Filipino',
        icon: 'translate',
        sortOrder: 1,
      ),
      Subject(
        id: 'subj_eng',
        name: 'English',
        description: 'Grammar, Reading Comprehension, and Vocabulary',
        icon: 'menu_book',
        sortOrder: 2,
      ),
      Subject(
        id: 'subj_mth',
        name: 'Math',
        description: 'Algebra, Geometry, Numerical & Mathematical Ability',
        icon: 'calculate',
        sortOrder: 3,
      ),
      Subject(
        id: 'subj_science',
        name: 'Science',
        description: 'Biology, Chemistry, and Physical Sciences',
        icon: 'biotech',
        sortOrder: 4,
      ),
    ];
  }

  static List<Topic> getTopics() {
    return const [
      Topic(
        id: 'top_fil',
        subjectId: 'subj_fil',
        name: 'Balarila at Sawikain',
        description: 'Wastong gamit ng mga salita at sawikain sa wikang Filipino',
        sortOrder: 1,
      ),
      Topic(
        id: 'top_eng',
        subjectId: 'subj_eng',
        name: 'Grammar & Vocabulary',
        description: 'Subject-verb agreement, idioms, and vocabulary in context',
        sortOrder: 2,
      ),
      Topic(
        id: 'top_mth',
        subjectId: 'subj_mth',
        name: 'Algebra & Arithmetic',
        description: 'Fractions, percentages, algebra word problems, and ratios',
        sortOrder: 3,
      ),
      Topic(
        id: 'top_bio',
        subjectId: 'subj_science',
        name: 'Cell Biology & Organisms',
        description: 'Cell organelles, photosynthesis, cellular respiration, and genetics',
        sortOrder: 4,
      ),
      Topic(
        id: 'top_chem',
        subjectId: 'subj_science',
        name: 'Basic Chemistry & Matter',
        description: 'Periodic table, chemical bonding, acids/bases, and reactions',
        sortOrder: 5,
      ),
    ];
  }

  static List<Question> getInitialQuestions() {
    return const [
      // 1. Multiple Choice - Filipino
      Question(
        id: 'q_fil_1',
        subjectId: 'subj_fil',
        topicId: 'top_fil',
        questionText: 'Piliin ang wastong salita: "Pumunta si Ana _____ palengke upang mamili ng gulay."',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.easy,
        explanation: 'Ang katagang "sa" ay ginagamit bilang pang-ukol na nagtuturo ng direksyon o pook.',
        reference: 'Balarila ng Wikang Pambansa',
        choices: [
          QuestionChoice(
            id: 'f1_1',
            questionId: 'q_fil_1',
            choiceText: 'sa',
            isCorrect: true,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'f1_2',
            questionId: 'q_fil_1',
            choiceText: 'ng',
            isCorrect: false,
            sortOrder: 1,
          ),
          QuestionChoice(
            id: 'f1_3',
            questionId: 'q_fil_1',
            choiceText: 'nang',
            isCorrect: false,
            sortOrder: 2,
          ),
          QuestionChoice(
            id: 'f1_4',
            questionId: 'q_fil_1',
            choiceText: 'may',
            isCorrect: false,
            sortOrder: 3,
          ),
        ],
      ),

      // 2. True / False - Filipino
      Question(
        id: 'q_fil_2',
        subjectId: 'subj_fil',
        topicId: 'top_fil',
        questionText: 'Ang sawikaing "nagbibilang ng poste" ay nangangahulugang walang trabaho o hanapbuhay.',
        questionType: QuestionType.trueFalse,
        difficulty: Difficulty.easy,
        explanation: 'Tama. Ang "nagbibilang ng poste" ay tanyag na sawikaing Tagalog para sa taong walang hanapbuhay.',
        reference: 'Mga Sawikain at Salawikaing Pilipino',
        choices: [
          QuestionChoice(
            id: 'f2_1',
            questionId: 'q_fil_2',
            choiceText: 'True',
            isCorrect: true,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'f2_2',
            questionId: 'q_fil_2',
            choiceText: 'False',
            isCorrect: false,
            sortOrder: 1,
          ),
        ],
      ),

      // 3. Multiple Choice - English Grammar
      Question(
        id: 'q_verb_1',
        subjectId: 'subj_eng',
        topicId: 'top_eng',
        questionText: 'Choose the sentence that observes correct grammatical agreement:',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.medium,
        explanation: '"Neither... nor" with singular subjects takes a singular verb: "Neither the manager nor the supervisor was present."',
        reference: 'Standard English Grammar: Correlative Conjunctions',
        choices: [
          QuestionChoice(
            id: 'c4_1',
            questionId: 'q_verb_1',
            choiceText: 'Neither the manager nor the supervisor were present.',
            isCorrect: false,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'c4_2',
            questionId: 'q_verb_1',
            choiceText: 'Neither the manager nor the supervisor was present.',
            isCorrect: true,
            sortOrder: 1,
          ),
          QuestionChoice(
            id: 'c4_3',
            questionId: 'q_verb_1',
            choiceText: 'Neither the manager nor the supervisor are present.',
            isCorrect: false,
            sortOrder: 2,
          ),
          QuestionChoice(
            id: 'c4_4',
            questionId: 'q_verb_1',
            choiceText: 'Neither the manager nor the supervisor have been present.',
            isCorrect: false,
            sortOrder: 3,
          ),
        ],
      ),

      // 4. Multiple Choice - English Vocabulary
      Question(
        id: 'q_eng_2',
        subjectId: 'subj_eng',
        topicId: 'top_eng',
        questionText: 'Choose the word that is most opposite in meaning to "CANDID":',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.medium,
        explanation: 'Candid means truthful and straightforward; its direct antonym is deceitful.',
        reference: 'English Lexicon & Antonyms',
        choices: [
          QuestionChoice(
            id: 'e2_1',
            questionId: 'q_eng_2',
            choiceText: 'Deceitful',
            isCorrect: true,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'e2_2',
            questionId: 'q_eng_2',
            choiceText: 'Honest',
            isCorrect: false,
            sortOrder: 1,
          ),
          QuestionChoice(
            id: 'e2_3',
            questionId: 'q_eng_2',
            choiceText: 'Blunt',
            isCorrect: false,
            sortOrder: 2,
          ),
          QuestionChoice(
            id: 'e2_4',
            questionId: 'q_eng_2',
            choiceText: 'Articulate',
            isCorrect: false,
            sortOrder: 3,
          ),
        ],
      ),

      // 5. Multiple Choice - Math Arithmetic
      Question(
        id: 'q_num_1',
        subjectId: 'subj_mth',
        topicId: 'top_mth',
        questionText: 'A company has 120 employees. If 65% of the employees work on-site, how many employees do NOT work on-site?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.medium,
        explanation: 'If 65% work on-site, 35% do not. 120 * 0.35 = 42 employees.',
        reference: 'Percentage and Basic Arithmetic Problem Solving',
        choices: [
          QuestionChoice(
            id: 'c5_1',
            questionId: 'q_num_1',
            choiceText: '38 employees',
            isCorrect: false,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'c5_2',
            questionId: 'q_num_1',
            choiceText: '42 employees',
            isCorrect: true,
            sortOrder: 1,
          ),
          QuestionChoice(
            id: 'c5_3',
            questionId: 'q_num_1',
            choiceText: '45 employees',
            isCorrect: false,
            sortOrder: 2,
          ),
          QuestionChoice(
            id: 'c5_4',
            questionId: 'q_num_1',
            choiceText: '78 employees',
            isCorrect: false,
            sortOrder: 3,
          ),
        ],
      ),

      // 6. Multiple Choice - Math Algebra
      Question(
        id: 'q_mth_dyn_1',
        subjectId: 'subj_mth',
        topicId: 'top_mth',
        questionText: 'If 3x + 7 = 22, what is the value of 2x - 3?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.medium,
        explanation: '3x = 15 => x = 5. Then 2(5) - 3 = 10 - 3 = 7.',
        reference: 'Algebra Fundamentals',
        choices: [
          QuestionChoice(
            id: 'm1_1',
            questionId: 'q_mth_dyn_1',
            choiceText: '7',
            isCorrect: true,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'm1_2',
            questionId: 'q_mth_dyn_1',
            choiceText: '5',
            isCorrect: false,
            sortOrder: 1,
          ),
          QuestionChoice(
            id: 'm1_3',
            questionId: 'q_mth_dyn_1',
            choiceText: '10',
            isCorrect: false,
            sortOrder: 2,
          ),
          QuestionChoice(
            id: 'm1_4',
            questionId: 'q_mth_dyn_1',
            choiceText: '12',
            isCorrect: false,
            sortOrder: 3,
          ),
        ],
      ),

      // 7. Multiple Choice - Science Biology
      Question(
        id: 'q_bio_1',
        subjectId: 'subj_science',
        topicId: 'top_bio',
        questionText: 'Which gas do plants primarily absorb during the process of photosynthesis?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.easy,
        explanation: 'Plants absorb carbon dioxide (CO2) from the air and water from the soil to produce glucose and oxygen using light energy.',
        reference: 'Campbell Biology: Photosynthesis Chapter',
        choices: [
          QuestionChoice(
            id: 'cb1_1',
            questionId: 'q_bio_1',
            choiceText: 'Oxygen',
            isCorrect: false,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'cb1_2',
            questionId: 'q_bio_1',
            choiceText: 'Carbon dioxide',
            isCorrect: true,
            sortOrder: 1,
          ),
          QuestionChoice(
            id: 'cb1_3',
            questionId: 'q_bio_1',
            choiceText: 'Nitrogen',
            isCorrect: false,
            sortOrder: 2,
          ),
          QuestionChoice(
            id: 'cb1_4',
            questionId: 'q_bio_1',
            choiceText: 'Hydrogen',
            isCorrect: false,
            sortOrder: 3,
          ),
        ],
      ),

      // 8. True / False - Science Biology
      Question(
        id: 'q_bio_2',
        subjectId: 'subj_science',
        topicId: 'top_bio',
        questionText: 'The mitochondria is the part of the cell responsible for producing most of its energy (ATP).',
        questionType: QuestionType.trueFalse,
        difficulty: Difficulty.easy,
        explanation: 'True. Mitochondria are often termed the "powerhouses of the cell" because they generate most of the chemical energy needed to power cellular reactions.',
        reference: 'Cellular Respiration and Energy Transformation',
        choices: [
          QuestionChoice(
            id: 'cb2_1',
            questionId: 'q_bio_2',
            choiceText: 'True',
            isCorrect: true,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'cb2_2',
            questionId: 'q_bio_2',
            choiceText: 'False',
            isCorrect: false,
            sortOrder: 1,
          ),
        ],
      ),

      // 9. Matching Type - Science Biology
      Question(
        id: 'q_bio_3',
        subjectId: 'subj_science',
        topicId: 'top_bio',
        questionText: 'Match each biological term to its correct definition:',
        questionType: QuestionType.matching,
        difficulty: Difficulty.medium,
        explanation: 'Photosynthesis converts light into chemical energy, osmosis is water diffusion across membranes, and mitosis produces two genetically identical daughter cells.',
        reference: 'Cell Biology Terminology',
        matchingPairs: [
          MatchingPair(
            id: 'mb_1',
            questionId: 'q_bio_3',
            leftText: 'Photosynthesis',
            rightText: 'Converts light into chemical energy',
          ),
          MatchingPair(
            id: 'mb_2',
            questionId: 'q_bio_3',
            leftText: 'Osmosis',
            rightText: 'Movement of water across a membrane',
          ),
          MatchingPair(
            id: 'mb_3',
            questionId: 'q_bio_3',
            leftText: 'Mitosis',
            rightText: 'Cell division producing identical cells',
          ),
        ],
      ),

      // 10. Multiple Choice - Science Chemistry
      Question(
        id: 'q_chem_1',
        subjectId: 'subj_science',
        topicId: 'top_chem',
        questionText: 'What is the pH level of pure distilled water at 25°C?',
        questionType: QuestionType.multipleChoice,
        difficulty: Difficulty.easy,
        explanation: 'A pH of 7 represents neutral water, where concentrations of hydrogen and hydroxide ions are equal.',
        reference: 'General Chemistry: Acids and Bases',
        choices: [
          QuestionChoice(
            id: 'ch1_1',
            questionId: 'q_chem_1',
            choiceText: 'pH 0',
            isCorrect: false,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'ch1_2',
            questionId: 'q_chem_1',
            choiceText: 'pH 7',
            isCorrect: true,
            sortOrder: 1,
          ),
          QuestionChoice(
            id: 'ch1_3',
            questionId: 'q_chem_1',
            choiceText: 'pH 10',
            isCorrect: false,
            sortOrder: 2,
          ),
          QuestionChoice(
            id: 'ch1_4',
            questionId: 'q_chem_1',
            choiceText: 'pH 14',
            isCorrect: false,
            sortOrder: 3,
          ),
        ],
      ),

      // 11. True / False - Science Chemistry
      Question(
        id: 'q_chem_2',
        subjectId: 'subj_science',
        topicId: 'top_chem',
        questionText: 'Water (H2O) is composed of two hydrogen atoms and one oxygen atom.',
        questionType: QuestionType.trueFalse,
        difficulty: Difficulty.easy,
        explanation: 'True. A water molecule consists of two hydrogen atoms bonded to a single oxygen atom.',
        reference: 'General Chemistry: Chemical Formulas',
        choices: [
          QuestionChoice(
            id: 'ch2_1',
            questionId: 'q_chem_2',
            choiceText: 'True',
            isCorrect: true,
            sortOrder: 0,
          ),
          QuestionChoice(
            id: 'ch2_2',
            questionId: 'q_chem_2',
            choiceText: 'False',
            isCorrect: false,
            sortOrder: 1,
          ),
        ],
      ),
    ];
  }
}
