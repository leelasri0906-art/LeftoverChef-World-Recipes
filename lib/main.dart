import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const LeftoverChefApp());

class LeftoverChefApp extends StatelessWidget {
  const LeftoverChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF16805D);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LeftoverChef',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF7FAF7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7FAF7),
          foregroundColor: Color(0xFF163B2D),
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const RecipeHomePage(),
    );
  }
}

class Recipe {
  final int id;
  final String name, country, cuisine, category, description;
  final int time, servings;
  final List<String> ingredients, instructions;

  Recipe.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String,
        country = json['country'] as String,
        cuisine = json['cuisine'] as String,
        category = json['category'] as String,
        description = json['description'] as String,
        time = json['time'] as int,
        servings = json['servings'] as int,
        ingredients = List<String>.from(json['ingredients'] as List),
        instructions = List<String>.from(json['instructions'] as List);
}

class RecipeHomePage extends StatefulWidget {
  const RecipeHomePage({super.key});

  @override
  State<RecipeHomePage> createState() => _RecipeHomePageState();
}

class _RecipeHomePageState extends State<RecipeHomePage> {
  List<Recipe> allRecipes = [];
  final Set<int> favorites = {};
  final TextEditingController searchController = TextEditingController();
  final TextEditingController ingredientsController = TextEditingController();
  String selectedCountry = 'All countries';
  String selectedCategory = 'All';
  bool ingredientMode = false;
  bool showFavorites = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRecipes();
  }

  Future<void> loadRecipes() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes.json');
      final data = jsonDecode(raw) as List<dynamic>;
      setState(() {
        allRecipes = data.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  List<String> get countries {
    final list = allRecipes.map((r) => r.country).toSet().toList()..sort();
    return ['All countries', ...list];
  }

  List<Recipe> get filteredRecipes {
    final query = searchController.text.trim().toLowerCase();
    final wanted = ingredientsController.text
        .toLowerCase()
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return allRecipes.where((r) {
      if (showFavorites && !favorites.contains(r.id)) return false;
      if (selectedCountry != 'All countries' && r.country != selectedCountry) return false;
      if (selectedCategory != 'All' && r.category != selectedCategory) return false;
      final text = '${r.name} ${r.country} ${r.cuisine} ${r.category} ${r.description} ${r.ingredients.join(' ')}'.toLowerCase();
      if (query.isNotEmpty && !text.contains(query)) return false;
      if (ingredientMode && wanted.isNotEmpty) {
        final recipeIngredients = r.ingredients.map((e) => e.toLowerCase()).toList();
        final matches = wanted.where((w) => recipeIngredients.any((ri) => ri.contains(w) || w.contains(ri))).length;
        if (matches == 0) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = filteredRecipes;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu_rounded, color: Color(0xFF16805D), size: 30),
            SizedBox(width: 10),
            Text('LeftoverChef', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: showFavorites ? 'Show all recipes' : 'Favorites',
            onPressed: () => setState(() => showFavorites = !showFavorites),
            icon: Icon(showFavorites ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : allRecipes.isEmpty
              ? const Center(child: Text('Could not load recipes. Check assets/recipes.json.'))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHero()),
                    SliverToBoxAdapter(child: _buildFilters()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(showFavorites ? 'Your favorites' : 'Explore recipes',
                                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                            ),
                            Text('${recipes.length} recipes', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                    if (recipes.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: Text('No recipes found. Try another search or filter.')),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            final columns = width > 1000 ? 4 : width > 650 ? 3 : width > 430 ? 2 : 1;
                            return SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: columns == 1 ? 1.55 : 0.82,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => RecipeCard(
                                  recipe: recipes[index],
                                  isFavorite: favorites.contains(recipes[index].id),
                                  onFavorite: () => setState(() {
                                    if (!favorites.add(recipes[index].id)) favorites.remove(recipes[index].id);
                                  }),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => RecipeDetailsPage(recipe: recipes[index]),
                                  )),
                                ),
                                childCount: recipes.length,
                              ),
                            );
                          },
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
                        child: Text(
                          'Recipe collection: 60+ home-style recipes inspired by cuisines around the world. Recipes are illustrative adaptations; ingredient availability and traditional methods vary by region.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0E6549), Color(0xFF23A477)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GOOD FOOD. LESS WASTE.', style: TextStyle(color: Color(0xFFD8F8E8), letterSpacing: 1.4, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Your kitchen,\\nthe whole world. 🌍', style: TextStyle(color: Colors.white, fontSize: 29, height: 1.12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Discover dishes by country or turn leftover ingredients into something delicious.', style: TextStyle(color: Colors.white, height: 1.4)),
          const SizedBox(height: 18),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() { ingredientMode = false; }),
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search recipes, ingredients, countries…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => searchController.clear())),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Find by ingredients', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: ingredientsController,
            onChanged: (_) => setState(() => ingredientMode = true),
            decoration: const InputDecoration(
              hintText: 'e.g. rice, tomato, onion',
              prefixIcon: Icon(Icons.kitchen_outlined),
              helperText: 'Separate ingredients with commas',
            ),
          ),
          const SizedBox(height: 14),
          const Text('Choose a country', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedCountry,
            isExpanded: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.public), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            items: countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => selectedCountry = v ?? 'All countries'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Vegetarian', 'Vegan', 'Non-vegetarian'].map((c) => ChoiceChip(
              label: Text(c),
              selected: selectedCategory == c,
              onSelected: (_) => setState(() => selectedCategory = c),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isFavorite;
  final VoidCallback onFavorite, onTap;
  const RecipeCard({super.key, required this.recipe, required this.isFavorite, required this.onFavorite, required this.onTap});

  IconData get dishIcon {
    final s = recipe.name.toLowerCase();
    if (s.contains('rice') || s.contains('biryani') || s.contains('pulao')) return Icons.rice_bowl;
    if (s.contains('soup') || s.contains('curry') || s.contains('stew')) return Icons.soup_kitchen;
    if (s.contains('pasta') || s.contains('noodle') || s.contains('ramen')) return Icons.ramen_dining;
    if (s.contains('salad') || s.contains('bowl')) return Icons.eco;
    if (s.contains('pizza') || s.contains('bread') || s.contains('toast')) return Icons.local_pizza;
    return Icons.restaurant;
  }

  Color get accent {
    const colors = [Color(0xFFE4F4E9), Color(0xFFFFEBD9), Color(0xFFE5EFFD), Color(0xFFF6E6F2), Color(0xFFFFF2C9)];
    return colors[recipe.id % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                color: accent,
                child: Stack(
                  children: [
                    Center(child: Icon(dishIcon, size: 70, color: const Color(0xFF277354))),
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(30)),
                        child: Text(recipe.country, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: IconButton(
                        onPressed: onFavorite,
                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.black54),
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.92)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(recipe.cuisine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 15, color: Color(0xFF16805D)),
                        const SizedBox(width: 4),
                        Text('${recipe.time} min', style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF16805D)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeDetailsPage extends StatelessWidget {
  final Recipe recipe;
  const RecipeDetailsPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(recipe.name)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F4E9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: Icon(Icons.restaurant_menu, size: 90, color: Color(0xFF16805D))),
          ),
          const SizedBox(height: 18),
          Text(recipe.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _infoChip(Icons.public, recipe.country),
            _infoChip(Icons.schedule, '${recipe.time} minutes'),
            _infoChip(Icons.people_alt_outlined, '${recipe.servings} servings'),
            _infoChip(Icons.eco_outlined, recipe.category),
          ]),
          const SizedBox(height: 14),
          Text(recipe.description, style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          const Text('Ingredients', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...recipe.ingredients.map((ingredient) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF16805D), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(ingredient, style: const TextStyle(fontSize: 15))),
            ]),
          )),
          const SizedBox(height: 24),
          const Text('How to make it', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...recipe.instructions.asMap().entries.map((entry) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 15, backgroundColor: const Color(0xFF16805D), child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.value, style: const TextStyle(height: 1.45))),
            ]),
          )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Chip(
    avatar: Icon(icon, size: 17, color: const Color(0xFF16805D)),
    label: Text(label),
    backgroundColor: const Color(0xFFEAF5EE),
    side: BorderSide.none,
  );
}
